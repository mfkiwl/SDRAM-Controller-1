`timescale 1ns/1ns

module tb_sdram_ctrl();

// Clock and Reset generate
logic clk=1'b1, rst_n=1'b0;
always  #5  clk = ~clk;  // 100MHz clock
initial #20 rst_n = 1'b1;

// user signals
logic wreq, wgnt;
logic [23:0] waddr;
logic [15:0] wdata;
logic rreq, rgnt;
logic [23:0] raddr;
logic [15:0] rdata;

// SDRAM signals
logic DRAM_CLK, DRAM_CKE, DRAM_CS_n, DRAM_WE_n, DRAM_CAS_n, DRAM_RAS_n;
logic [ 1:0] DRAM_DQM;
logic [12:0] DRAM_ADDR;
logic [ 1:0] DRAM_BA;
tri   [15:0] DRAM_DQ;
assign DRAM_DQ = 'z;
    
sdram_ctrl sdram_ctrl_i (
    .clk           ( clk         ),
    .rst_n         ( rst_n       ),
    .wreq          ( wreq        ),
    .wgnt          ( wgnt        ),
    .waddr         ( waddr       ),
    .wdata         ( wdata       ),
    .rreq          ( rreq        ),
    .rgnt          ( rgnt        ),
    .raddr         ( raddr       ),
    .rdata         ( rdata       ),
        
    .sdram_addr    ( DRAM_ADDR   ),
    .sdram_ba      ( DRAM_BA     ),
    .sdram_dq      ( DRAM_DQ     ),
    .sdram_dqm     ( DRAM_DQM    ),
    .sdram_clk     ( DRAM_CLK    ),
    .sdram_cke     ( DRAM_CKE    ),
    .sdram_cs_n    ( DRAM_CS_n   ),
    .sdram_ras_n   ( DRAM_RAS_n  ),
    .sdram_cas_n   ( DRAM_CAS_n  ),
    .sdram_we_n    ( DRAM_WE_n   )
);

task automatic WriteBusAction(input _wreq=1'b0, input [23:0] _waddr='0, input [15:0] _wdata='0);
    wreq  = _wreq;
    waddr = _waddr;
    wdata = _wdata;
endtask

task automatic  ReadBusAction(input _rreq=1'b0, input [23:0] _raddr='0);
    rreq  = _rreq;
    raddr = _raddr;
endtask

// simulation signal generate
initial begin
    WriteBusAction();
    ReadBusAction();
    # 50 WriteBusAction(1,2,3);
    #100 WriteBusAction();
    # 50  ReadBusAction(1,5);
    #100  ReadBusAction();
    #100 $finish;
end

initial begin            
    $dumpfile("tb_sdram_ctrl.vcd");
    $dumpvars(0,tb_sdram_ctrl);
end

endmodule