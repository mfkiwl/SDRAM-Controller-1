
module top(
    // Clock(50MHz) and Reset.
    input  logic CLK_B5B, RST_N,
    // FAN control
    output logic FAN_CTRL,
    // UART to USB
    output logic UART_TX,
    input  logic UART_RX,
    // SDR SDRAM
    output logic DRAM_CLK, DRAM_CKE, DRAM_LDQM, DRAM_UDQM, DRAM_CS_n, DRAM_WE_n, DRAM_CAS_n, DRAM_RAS_n,
    output logic [12:0] DRAM_ADDR,
    output logic [ 1:0] DRAM_BA,
    inout        [15:0] DRAM_DQ
);

assign FAN_CTRL = 1'b1; // always turn on the fan

wire rst_n = RST_N;    // low Reset
wire clk   = CLK_B5B;  // 50MHz Clock

logic wreq, wgnt;
logic [24-1:0] waddr;
logic [16-1:0] wdata;
logic rreq, rgnt;
logic [24-1:0] raddr;
logic [16-1:0] rdata;

debug_uart #(  // this module convert  UART command to bus read/write request
    .UART_RX_CLK_DIV  ( 108     ), // 50MHz/4/115200Hz=108
    .UART_TX_CLK_DIV  ( 434     ), // 50MHz/1/115200Hz=434
    .ADDR_BYTE_WIDTH  ( 3       ), // addr width = 3byte(24bit)
    .DATA_BYTE_WIDTH  ( 2       ), // data width = 2byte(16bit)
    .READ_IMM         ( 1       )  // 1: read immediately: Capture rdata in the clock cycle of rgnt=1
) debug_uart_inst(
    .clk              ( clk     ),
    .rst_n            ( rst_n   ),
    
    .wreq             ( wreq    ),
    .wgnt             ( wgnt    ),
    .waddr            ( waddr   ),
    .wdata            ( wdata   ),
    
    .rreq             ( rreq    ),
    .rgnt             ( rgnt    ),
    .raddr            ( raddr   ),
    .rdata            ( rdata   ),
    
    .uart_tx          ( UART_TX ),
    .uart_rx          ( UART_RX )
);

sdram_ctrl #(
    .CLK_FREQUENCY ( 50                     ),  // clock = 50MHz
    .ROW_WIDTH     ( 13                     ),
    .COL_WIDTH     ( 9                      ),
    .BANK_WIDTH    ( 2                      )
) sdram_ctrl_i (
    .clk           ( clk                    ),  // clock = 50MHz
    .rst_n         ( rst_n                  ),
    .wreq          ( wreq                   ),
    .wgnt          ( wgnt                   ),
    .waddr         ( waddr                  ),
    .wdata         ( wdata                  ),
    .rreq          ( rreq                   ),
    .rgnt          ( rgnt                   ),
    .raddr         ( raddr                  ),
    .rdata         ( rdata                  ),
        
    .sdram_addr    ( DRAM_ADDR              ),
    .sdram_ba      ( DRAM_BA                ),
    .sdram_dq      ( DRAM_DQ                ),
    .sdram_dqm     ( {DRAM_UDQM, DRAM_LDQM} ),
    .sdram_clk     ( DRAM_CLK               ),
    .sdram_cke     ( DRAM_CKE               ),
    .sdram_cs_n    ( DRAM_CS_n              ),
    .sdram_ras_n   ( DRAM_RAS_n             ),
    .sdram_cas_n   ( DRAM_CAS_n             ),
    .sdram_we_n    ( DRAM_WE_n              )
);

endmodule
