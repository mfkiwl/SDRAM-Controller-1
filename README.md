FPGA SDRAM controller
===========================
拥有极简用户接口的 SDR SDRAM 控制器

# 模块说明

核心模块在 [./RTL/sdram_ctrl.sv](https://github.com/WangXuan95/SDRAM-Controller/blob/master/RTL/sdram_ctrl.sv)，该模块接口定义见以下注释：

```SystemVerilog
module sdram_ctrl #(   // SDRAM 控制器模块
    parameter CLK_FREQUENCY = 100, // 指定时钟频率，模块内依据此决定刷新间隔周期数
    parameter  ROW_WIDTH = 13, // SDRAM 行地址宽度，取决于SDRAM具体型号
    parameter  COL_WIDTH = 9,  // SDRAM 列地址宽度，取决于SDRAM具体型号
    parameter BANK_WIDTH = 2   // SDRAM BANK地址宽度，取决于SDRAM具体型号
) (
    // 时钟和复位，时钟频率请和 parameter CLK_FREQUENCY 保持一致， 低电平复位
    input  logic  clk, rst_n,
    
    // 写接口，见时序图
    input  logic                                      wreq,
    output logic                                      wgnt,
    input  logic [BANK_WIDTH+ROW_WIDTH+COL_WIDTH-1:0] waddr,
    input  logic                             [16-1:0] wdata,
    
    // 读接口，见时序图
    input  logic                                      rreq,
    output logic                                      rgnt,
    input  logic [BANK_WIDTH+ROW_WIDTH+COL_WIDTH-1:0] raddr,
    output logic                             [16-1:0] rdata,
    
    // SDRAM 信号接口
    output logic [(ROW_WIDTH>COL_WIDTH?ROW_WIDTH:COL_WIDTH)-1:0] sdram_addr,
    output logic [BANK_WIDTH-1:0]                                sdram_ba,
    inout        [15:0]                                          sdram_dq,
    output logic [ 1:0]                                          sdram_dqm,
    output logic sdram_clk, sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n
);
```

# 时序图

![写时序图（左）、读时序图（右）](https://github.com/WangXuan95/SDRAM-Controller/blob/master/timing.png)

如上图，左图是写时序，右图是读时序。这些信号都 **与clk的上升沿对齐** 。

* 写时，将wreq置高，同时给出 waddr 和 wdata ，直到若干clk周期后， wgnt 变高，则说明 wdata 已经写入 waddr 中。（注：wreq=1时，waddr和wdata需要保持直到wgnt=1）
* 读时，将rreq置高，同时给出 raddr ，直到若干clk周期后，rgnt变高，同时rdata上读出数据。（注：rreq=1时，raddr需要保持直到rgnt=1）

# 示例

该库提供了一个使用 UART 命令读写 SDRAM 的示例。要测试该示例，你需要一个 **有UART和SDRAM的FPGA开发板** 。

[./Test_C5P_OpenVINO 文件夹](https://github.com/WangXuan95/SDRAM-Controller/blob/master/Test_C5P_OpenVINO)中是一个 基于 [C5P OpenVINO开发板](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=167&No=1159) 的Quartus工程。你可以修改引脚定义以适配你的开发板。

编译综合上传后，用任意一种串口终端（例如PUTTY）打开开发板的UART，然后输入读写命令：

* 输入 **addr\n** 可以读出 SDRAM addr 地址处的数据（以十六进制），例如，输入 **1234ab\n** 能读出 地址 0x1234ab 处的数据。
* 输入 **addr data\n** 可以将 data 写入SDRAM地址addr（以十六进制），例如，输入 **1234ab 93beef\n** 代表将 0x93beef 写入 地址0x1234ab。
