`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 08:55:48 PM
// Design Name: 
// Module Name: dmac_peri2accel_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dmac_peri2accel_top#(
    parameter NUM_MASTERS = 2,
    parameter ADDR_WIDTH = 24,
    parameter BURST_WIDTH = 8,
    parameter DATA_WIDTH_BYTE = 1    // byte unit, 1: 8bit, 2: 16bit, 4: 32bit, 8: 64bit
)(
    input                           clk_i,
    input                           resetn_i,

    //connect to acclerator port
    input                           AWVALID_i,
    output                          AWREADY_o,
    input       [ADDR_WIDTH-1:0]    AWADDR_i,
    input       [BURST_WIDTH-1:0]   AWBURST_i,

    input                           ARVALID_i,
    output                          ARREADY_o,
    input       [ADDR_WIDTH-1:0]    ARADDR_i,
    input       [BURST_WIDTH-1:0]   ARBURST_i,  

    ////           // AXI-STREAM port//////////////////////////////////////        
    ///////////////// AXIS-MASTER port
    /////////////////////////////////////////////////
    //master interface port
    /////////////////////////////////////////////////
    output                          m_tvalid_o,
    input                           m_tready_i,
    output  [DATA_WIDTH_BYTE*8-1:0] m_tdata_o,
    output  [DATA_WIDTH_BYTE-1:0]   m_tstrb_o,
    output  [DATA_WIDTH_BYTE-1:0]   m_tkeep_o,
    output                          m_tlast_o,

    ///////////////// AXIS-SLAVE port
    /////////////////////////////////////////////////
    //slave interface port
    /////////////////////////////////////////////////
    input                           s_tvalid_i,
    output                          s_tready_o,
    input  [DATA_WIDTH_BYTE*8-1:0]  s_tdata_i,
    input  [DATA_WIDTH_BYTE-1:0]    s_tstrb_i,
    input  [DATA_WIDTH_BYTE-1:0]    s_tkeep_i,
    input                           s_tlast_i,

    // HyperBus
    inout   [7:0]                dq_io,
    inout                        rwds_io,

	output                       hclk_p,  // For 3V RAMs, just use the single-ended (positive) clock
	output                       hclk_n,

	output                       cs_n

    );

    wire              start;
    wire              start_rdy;
    wire  [47:0]      cmd_addr;
    wire  [7:0]       burst_len;
    wire  [3:0]       latency;
    wire  [3:0]       recovery;
    wire  [1:0]       capture_shmoo;

    wire              wr_read_fifo;
    wire              tlast_read_fifo;
    wire              tlast_write_fifo;
                  
    


    dmac_peri2accel #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_WIDTH(BURST_WIDTH)
    ) coordinator_center_dmac (
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .start_o(start),
        .start_ready_i(start_rdy),
        .cmd_addr_o(cmd_addr),
        .burst_len_o(burst_len),
        .latency_o(latency),
        .recovery_o(recovery),
        .capture_shmoo_o(capture_shmoo),
        .wr_read_fifo_i(wr_read_fifo),
        .tlast_read_fifo_o(tlast_read_fifo),
        .tlast_write_fifo_i(tlast_write_fifo),
        .AWVALID_i(AWVALID_i),
        .AWREADY_o(AWREADY_o),
        .AWADDR_i(AWADDR_i),
        .AWBURST_i(AWBURST_i),
        .ARVALID_i(ARVALID_i),
        .ARREADY_o(ARREADY_o),
        .ARADDR_i(ARADDR_i),
        .ARBURST_i(ARBURST_i)
    );

    hyperbus_master #(
        .W_BURSTLEN        (8),  // Thay đổi giá trị parameter ở đây nếu cần
        .ADDR_WIDTH_FIFO   (8),
        .DATA_WIDTH_FIFO   (8),
        .DATA_WIDTH_BYTE   (1),
        .INTERFACE_MOD     (1)   // 0: FIFO interface, 1: AXIS interface
    ) u_hyperbus_master (
        // System Clock and Reset
        .clk               (clk_i),               // input
        .rst_n             (resetn_i),             // input

        // Control Signals
        .cmd_addr          (cmd_addr),          // input  [47:0]
        .start             (start),             // input
        .start_rdy         (start_rdy),         // output
        .burst_len         (burst_len),         // input  [W_BURSTLEN-1:0]
        .latency           (latency),           // input  [3:0]
        .recovery          (recovery),          // input  [3:0]
        .capture_shmoo     (capture_shmoo),     // input  [1:0]

        // // Standard Data/FIFO Interface
        // .wdata_i           (),           // input  [7:0]
        // .wr_i              (),              // input
        // .rdata_o           (),           // output [7:0]
        // .rd_i              (),              // input
        // .full_o            (),            // output
        // .empty_o           (),           // output

        // Physical HyperBus Interface
        .dq_io             (dq_io),             // inout  [7:0]
        .rwds_io           (rwds_io),           // inout
        .hclk_p            (hclk_p),            // output
        .hclk_n            (hclk_n),            // output
        .cs_n              (cs_n),              // output

        // AXI-STREAM MASTER port (Read Data out)
        .m_tvalid_o        (m_tvalid_o),        // output
        .m_tready_i        (m_tready_i),        // input
        .m_tdata_o         (m_tdata_o),         // output [DATA_WIDTH_BYTE*8-1:0]
        .m_tstrb_o         (m_tstrb_o),         // output [DATA_WIDTH_BYTE-1:0]
        .m_tkeep_o         (m_tkeep_o),         // output [DATA_WIDTH_BYTE-1:0]
        .m_tlast_o         (m_tlast_o),         // output

        // AXI-STREAM SLAVE port (Write Data in)
        .s_tvalid_i        (s_tvalid_i),        // input
        .s_tready_o        (s_tready_o),        // output
        .s_tdata_i         (s_tdata_i),         // input  [DATA_WIDTH_BYTE*8-1:0]
        .s_tstrb_i         (s_tstrb_i),         // input  [DATA_WIDTH_BYTE-1:0]
        .s_tkeep_i         (s_tkeep_i),         // input  [DATA_WIDTH_BYTE-1:0]
        .s_tlast_i         (s_tlast_i),         // input

        // Additional FIFO Control
        .wr_read_fifo_o    (wr_read_fifo),    // output
        .tlast_read_fifo_i (tlast_read_fifo), // input
        .tlast_write_fifo_o(tlast_write_fifo) // output
    );


    



endmodule
