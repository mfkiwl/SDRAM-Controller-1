
module sdram_ctrl #(
    parameter CLK_FREQUENCY = 100,
    parameter  ROW_WIDTH = 13,
    parameter  COL_WIDTH = 9,
    parameter BANK_WIDTH = 2
) (
    // Host interface Clock, and Reset(Active-Low)
    input  logic  clk, rst_n,
    // Host write interface
    input  logic                                      wreq,
    output logic                                      wgnt,
    input  logic [BANK_WIDTH+ROW_WIDTH+COL_WIDTH-1:0] waddr,
    input  logic                             [16-1:0] wdata,
    // Host read interface
    input  logic                                      rreq,
    output logic                                      rgnt,
    input  logic [BANK_WIDTH+ROW_WIDTH+COL_WIDTH-1:0] raddr,
    output logic                             [16-1:0] rdata,
    // SDRAM interface
    output logic [(ROW_WIDTH>COL_WIDTH?ROW_WIDTH:COL_WIDTH)-1:0] sdram_addr,
    output logic [BANK_WIDTH-1:0]                                sdram_ba,
    inout        [15:0]                                          sdram_dq,
    output logic [ 1:0]                                          sdram_dqm,
    output logic sdram_clk, sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n
);

localparam SDRADDR_WIDTH = ROW_WIDTH > COL_WIDTH ? ROW_WIDTH : COL_WIDTH;
localparam HADDR_WIDTH = BANK_WIDTH + ROW_WIDTH + COL_WIDTH;

localparam REFRESH_TIME =  32;   // ms     (how often we need to refresh)
localparam REFRESH_COUNT = 8192; // cycles (how many refreshes required per refresh time)

// clk / refresh =  clk / sec
//                , sec / refbatch
//                , ref / refbatch
localparam CYCLES_BETWEEN_REFRESH = ( CLK_FREQUENCY
                                      * 1_000
                                      * REFRESH_TIME
                                    ) / REFRESH_COUNT;

// STATES - State
localparam IDLE      = 5'b00000;

localparam INIT_NOP1 = 5'b01000,
           INIT_PRE1 = 5'b01001,
           INIT_NOP1_1=5'b00101,
           INIT_REF1 = 5'b01010,
           INIT_NOP2 = 5'b01011,
           INIT_REF2 = 5'b01100,
           INIT_NOP3 = 5'b01101,
           INIT_LOAD = 5'b01110,
           INIT_NOP4 = 5'b01111;

localparam REF_PRE  =  5'b00001,
           REF_NOP1 =  5'b00010,
           REF_REF  =  5'b00011,
           REF_NOP2 =  5'b00100;

localparam READ_ACT  = 5'b10000,
           READ_NOP1 = 5'b10001,
           READ_CAS  = 5'b10010,
           READ_NOP2 = 5'b10011,
           READ_READ = 5'b10100;

localparam WRIT_ACT  = 5'b11000,
           WRIT_NOP1 = 5'b11001,
           WRIT_CAS  = 5'b11010,
           WRIT_NOP2 = 5'b11011;

// Commands              CCRCWBBA
//                       ESSSE100
localparam CMD_PALL = 8'b10010001,
           CMD_REF  = 8'b10001000,
           CMD_NOP  = 8'b10111000,
           CMD_MRS  = 8'b1000000x,
           CMD_BACT = 8'b10011xxx,
           CMD_READ = 8'b10101xx1,
           CMD_WRIT = 8'b10100xx1;


reg  [HADDR_WIDTH-1:0]   wr_addr;
reg  [15:0]              wr_data;
reg                      wr_enable;
reg  [HADDR_WIDTH-1:0]   rd_addr;
reg                      rd_enable;
wire                     rd_ready;
reg                      busy;

reg rvalid=1'b0, wvalid=1'b0;

enum {INIT, RWIDLE, RREQ, RWAIT, WREQ, WWAIT} status = INIT;

always @ (posedge clk or negedge rst_n)
    if(~rst_n) begin
        status <= INIT;
        rvalid <= 1'b0;
        wvalid <= 1'b0;
        rd_enable <= 1'b0;
        wr_enable <= 1'b0;
        rd_addr   <= '0;
        wr_enable <= 1'b0;
        wr_addr   <= '0;
        wr_data   <= '0;
    end else begin
        case(status)
        INIT: begin
            rvalid <= 1'b0;
            wvalid <= 1'b0;
            if(~busy)
                status <= RWIDLE;
        end
        RWIDLE: begin
            rd_enable <= 1'b0;
            wr_enable <= 1'b0;
            if(~busy) begin
                if(rreq) begin
                    if( ~rvalid || (rd_addr!=raddr) ) begin
                        rd_enable <= 1'b1;
                        rd_addr   <= raddr;
                        status    <= RREQ;
                    end
                end else if(wreq) begin
                    rvalid <= 1'b0;
                    if( ~wvalid || (wr_addr!=waddr) || (wr_data!=wdata) ) begin
                        wr_enable <= 1'b1;
                        wr_addr   <= waddr;
                        wr_data   <= wdata;
                        status    <= WREQ;
                    end
                end
            end
        end
        RREQ: begin
            wr_enable <= 1'b0;
            if(busy) begin
                rd_enable <= 1'b0;
                status    <= RWAIT;
            end else begin
                rd_enable <= 1'b1;
                
            end
        end
        RWAIT: begin
            rd_enable <= 1'b0;
            wr_enable <= 1'b0;
            if(rd_ready) begin
                status <= RWIDLE;
                rvalid <= rreq && (rd_addr==raddr);
            end else if(~busy) begin
                status <= RWIDLE;
                rvalid <= 1'b0;
            end
        end
        WREQ: begin
            rd_enable <= 1'b0;
            if(busy) begin
                wr_enable <= 1'b0;
                status    <= WWAIT;
            end else
                wr_enable <= 1'b1;
        end
        WWAIT: begin
            rd_enable <= 1'b0;
            wr_enable <= 1'b0;
            if(~busy) begin
                status <= RWIDLE;
                wvalid <= 1'b1;
            end
        end
        endcase
    end
    
assign rgnt  = rreq && (rd_addr==raddr) &&                     ( (rd_ready&&(status==RWAIT)) || (rvalid&(status==RWIDLE)) );
assign wgnt  = wreq && (wr_addr==waddr) && (wr_addr==waddr) && ( ( ~busy  &&(status==WWAIT)) || (wvalid&(status==RWIDLE)) );

// I/O Registers
reg  [HADDR_WIDTH-1:0]   haddr_r;
reg  [15:0]              wr_data_r;
reg  [15:0]              rd_data_r;
reg                      data_mask_low_r;
reg                      data_mask_high_r;
reg [SDRADDR_WIDTH-1:0]  addr_r;
reg [BANK_WIDTH-1:0]     sdram_ba_r;
reg                      rd_ready_r;

wire [15:0]              data_output;

assign sdram_clk = clk;
assign sdram_dqm = {data_mask_high_r, data_mask_low_r};
assign rdata = rd_data_r;

/* Internal Wiring */
reg [3:0] state_cnt;
reg [9:0] refresh_cnt;

reg [7:0] command;
reg [4:0] state;

// TODO output sdram_addr[6:4] when programming mode register

reg [7:0] command_nxt;
reg [3:0] state_cnt_nxt;
reg [4:0] next;

assign {sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} = command[7:3];
// state[4] will be set if mode is read/write
assign sdram_ba      = (state[4]) ? sdram_ba_r : command[2:1];
assign sdram_addr           = (state[4] | state == INIT_LOAD) ? addr_r : { {SDRADDR_WIDTH-11{1'b0}}, command[0], 10'd0 };

assign sdram_dq = (state == WRIT_CAS) ? wr_data_r : 16'bz;
assign rd_ready = rd_ready_r;

// HOST INTERFACE
// all registered on posedge
always @ (posedge clk)
  if (~rst_n) begin
    state <= INIT_NOP1;
    command <= CMD_NOP;
    state_cnt <= 4'hf;

    haddr_r <= {HADDR_WIDTH{1'b0}};
    wr_data_r <= 16'b0;
    rd_data_r <= 16'b0;
    busy <= 1'b0;
  end else begin
    state <= next;
    command <= command_nxt;

    if (!state_cnt)
      state_cnt <= state_cnt_nxt;
    else
      state_cnt <= state_cnt - 1'b1;

    if (wr_enable)
      wr_data_r <= wr_data;

    if (state == READ_READ)
      begin
      rd_data_r <= sdram_dq;
      rd_ready_r <= 1'b1;
      end
    else
      rd_ready_r <= 1'b0;

    busy <= state[4];

    if (rd_enable)
      haddr_r <= rd_addr;
    else if (wr_enable)
      haddr_r <= wr_addr;

    end

// Handle refresh counter
always @ (posedge clk)
 if (~rst_n)
   refresh_cnt <= 10'b0;
 else
   if (state == REF_NOP2)
     refresh_cnt <= 10'b0;
   else
     refresh_cnt <= refresh_cnt + 1'b1;


/* Handle logic for sending addresses to SDRAM based on current state*/
always @* begin
    if (state[4])
      {data_mask_low_r, data_mask_high_r} = 2'b00;
    else
      {data_mask_low_r, data_mask_high_r} = 2'b11;

   sdram_ba_r = 2'b00;
   addr_r = {SDRADDR_WIDTH{1'b0}};

   if (state == READ_ACT | state == WRIT_ACT)
     begin
     sdram_ba_r = haddr_r[HADDR_WIDTH-1:HADDR_WIDTH-(BANK_WIDTH)];
     addr_r = haddr_r[HADDR_WIDTH-(BANK_WIDTH+1):HADDR_WIDTH-(BANK_WIDTH+ROW_WIDTH)];
     end
   else if (state == READ_CAS | state == WRIT_CAS)
     begin
     // Send Column Address
     // Set bank to bank to precharge
     sdram_ba_r = haddr_r[HADDR_WIDTH-1:HADDR_WIDTH-(BANK_WIDTH)];

     // Examples for math
     //               BANK  ROW    COL
     // HADDR_WIDTH   2 +   13 +   9   = 24
     // SDRADDR_WIDTH 13

     // Set CAS address to:
     //   0s,
     //   1 (A10 is always for auto precharge),
     //   0s,
     //   column address
     addr_r = {
               {SDRADDR_WIDTH-(11){1'b0}},
               1'b1,                       /* A10 */
               {10-COL_WIDTH{1'b0}},
               haddr_r[COL_WIDTH-1:0]
              };
     end
   else if (state == INIT_LOAD)
     begin
     // Program mode register during load cycle
     //                                       B  C  SB
     //                                       R  A  EUR
     //                                       S  S-3Q ST
     //                                       T  654L210
     addr_r = {{SDRADDR_WIDTH-10{1'b0}}, 10'b1000110000};
     end
end

// Next state logic
always @*
begin
   state_cnt_nxt = 4'd0;
   command_nxt = CMD_NOP;
   if (state == IDLE)
        // Monitor for refresh or hold
        if (refresh_cnt >= CYCLES_BETWEEN_REFRESH)
          begin
          next = REF_PRE;
          command_nxt = CMD_PALL;
          end
        else if (rd_enable)
          begin
          next = READ_ACT;
          command_nxt = CMD_BACT;
          end
        else if (wr_enable)
          begin
          next = WRIT_ACT;
          command_nxt = CMD_BACT;
          end
        else
          begin
          // HOLD
          next = IDLE;
          end
    else
      if (!state_cnt)
        case (state)
          // INIT ENGINE
          INIT_NOP1:
            begin
            next = INIT_PRE1;
            command_nxt = CMD_PALL;
            end
          INIT_PRE1:
            begin
            next = INIT_NOP1_1;
            end
          INIT_NOP1_1:
            begin
            next = INIT_REF1;
            command_nxt = CMD_REF;
            end
          INIT_REF1:
            begin
            next = INIT_NOP2;
            state_cnt_nxt = 4'd7;
            end
          INIT_NOP2:
            begin
            next = INIT_REF2;
            command_nxt = CMD_REF;
            end
          INIT_REF2:
            begin
            next = INIT_NOP3;
            state_cnt_nxt = 4'd7;
            end
          INIT_NOP3:
            begin
            next = INIT_LOAD;
            command_nxt = CMD_MRS;
            end
          INIT_LOAD:
            begin
            next = INIT_NOP4;
            state_cnt_nxt = 4'd1;
            end
          // INIT_NOP4: default - IDLE

          // REFRESH
          REF_PRE:
            begin
            next = REF_NOP1;
            end
          REF_NOP1:
            begin
            next = REF_REF;
            command_nxt = CMD_REF;
            end
          REF_REF:
            begin
            next = REF_NOP2;
            state_cnt_nxt = 4'd7;
            end
          // REF_NOP2: default - IDLE

          // WRITE
          WRIT_ACT:
            begin
            next = WRIT_NOP1;
            state_cnt_nxt = 4'd1;
            end
          WRIT_NOP1:
            begin
            next = WRIT_CAS;
            command_nxt = CMD_WRIT;
            end
          WRIT_CAS:
            begin
            next = WRIT_NOP2;
            state_cnt_nxt = 4'd1;
            end
          // WRIT_NOP2: default - IDLE

          // READ
          READ_ACT:
            begin
            next = READ_NOP1;
            state_cnt_nxt = 4'd1;
            end
          READ_NOP1:
            begin
            next = READ_CAS;
            command_nxt = CMD_READ;
            end
          READ_CAS:
            begin
            next = READ_NOP2;
            state_cnt_nxt = 4'd1;
            end
          READ_NOP2:
            begin
            next = READ_READ;
            end
          // READ_READ: default - IDLE

          default:
            begin
            next = IDLE;
            end
          endcase
      else
        begin
        // Counter Not Reached - HOLD
        next = state;
        command_nxt = command;
        end
end

endmodule

