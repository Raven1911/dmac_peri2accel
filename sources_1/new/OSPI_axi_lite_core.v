`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 08:38:04 PM
// Design Name: 
// Module Name: OSPI_axi_lite_core
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

module OSPI_axi_lite_core #( 
    // ========================================================
    // AXI-LITE CONFIGURATION (CPU PORT)
    // ========================================================
    parameter NUM_MASTERS           = 1,
    parameter ADDR_WIDTH            = 32,          // AXI-Lite Address width
    parameter DATA_WIDTH            = 32,          // AXI-Lite Data width
    parameter TRANS_W_STRB_W        = 4,           // width strobe
    parameter TRANS_WR_RESP_W       = 2,           // width response
    parameter TRANS_PROT            = 3,
    parameter CYCLE_CLOCK           = 2,

    // Config register memory map
    parameter [ADDR_WIDTH-1:0] ADDR_REGISTERS_0 = 32'h0200_5000,
    parameter [ADDR_WIDTH-1:0] ADDR_REGISTERS_1 = 32'h0200_5004,
    parameter [ADDR_WIDTH-1:0] ADDR_REGISTERS_2 = 32'h0200_5008,
    parameter [ADDR_WIDTH-1:0] ADDR_REGISTERS_3 = 32'h0200_500C,
    parameter [ADDR_WIDTH-1:0] ADDR_REGISTERS_4 = 32'h0200_5010,
    parameter [ADDR_WIDTH-1:0] ADDR_REGISTERS_5 = 32'h0200_5014, // NEW: Mode Selection Register

    // ========================================================
    // ACCEL PORT CONFIGURATION (DMAC & AXIS)
    // ========================================================
    parameter ADDR_WIDTH_DMAC       = 24,
    parameter BURST_WIDTH           = 8,
    parameter DATA_WIDTH_BYTE       = 1            // 1: 8bit, 2: 16bit, 4: 32bit, 8: 64bit
)(  
    // ========================================================
    // 1. SYSTEM SIGNALS
    // ========================================================
    input                           clk,
    input                           resetn,

    // ========================================================
    // 2. AXI-LITE INTERFACE (CPU)
    // ========================================================
    // Write Address Channel
    input       [ADDR_WIDTH-1:0]        i_axi_awaddr,
    input                               i_axi_awvalid,
    output                              o_axi_awready,
    input       [TRANS_PROT-1:0]        i_axi_awprot,

    // Write Data Channel
    input       [DATA_WIDTH-1:0]        i_axi_wdata,
    input       [TRANS_W_STRB_W-1:0]    i_axi_wstrb,
    input                               i_axi_wvalid,
    output                              o_axi_wready,

    // Write Response Channel
    output      [TRANS_WR_RESP_W-1:0]   o_axi_bresp,
    output                              o_axi_bvalid,
    input                               i_axi_bready,

    // Read Address Channel
    input       [ADDR_WIDTH-1:0]        i_axi_araddr,
    input                               i_axi_arvalid,
    output                              o_axi_arready,
    input       [TRANS_PROT-1:0]        i_axi_arprot,

    // Read Data Channel
    output      [DATA_WIDTH-1:0]        o_axi_rdata,
    output                              o_axi_rvalid,
    output      [TRANS_WR_RESP_W-1:0]   o_axi_rresp,
    input                               i_axi_rready,

    // ========================================================
    // 3. ACCEL COMMAND PORT (AXI to DMAC)
    // ========================================================
    input                               AWVALID_i,
    output                              AWREADY_o,
    input       [ADDR_WIDTH_DMAC-1:0]   AWADDR_i,
    input       [BURST_WIDTH-1:0]       AWBURST_i,

    input                               ARVALID_i,
    output                              ARREADY_o,
    input       [ADDR_WIDTH_DMAC-1:0]   ARADDR_i,
    input       [BURST_WIDTH-1:0]       ARBURST_i,  

    // ========================================================
    // 4. ACCEL DATA PORT (AXI-STREAM)
    // ========================================================
    // --- Master Port (Read data out for Accel) ---
    output                          m_tvalid_o,
    input                           m_tready_i,
    output  [DATA_WIDTH_BYTE*8-1:0] m_tdata_o,
    output  [DATA_WIDTH_BYTE-1:0]   m_tstrb_o,
    output  [DATA_WIDTH_BYTE-1:0]   m_tkeep_o,
    output                          m_tlast_o,

    // --- Slave Port (Write data in from Accel) ---
    input                           s_tvalid_i,
    output                          s_tready_o,
    input   [DATA_WIDTH_BYTE*8-1:0] s_tdata_i,
    input   [DATA_WIDTH_BYTE-1:0]   s_tstrb_i,
    input   [DATA_WIDTH_BYTE-1:0]   s_tkeep_i,
    input                           s_tlast_i,

    // ========================================================
    // 5. EXTERNAL HYPERBUS PHYSICAL PINS
    // ========================================================
    inout   [7:0]                   dq_io,
    inout                           rwds_io,
    output                          hclk_p,
    output                          hclk_n,
    output                          cs_n
);

    // ========================================================
    // INTERNAL WIRES DECLARATION
    // ========================================================
    // AXI-Lite internal connections
    wire [ADDR_WIDTH-1:0]           o_addr_w;
    wire [ADDR_WIDTH-1:0]           o_addr_r;                
    wire [DATA_WIDTH-1:0]           o_data_w;
    wire [DATA_WIDTH-1:0]           i_data_r;
    wire                            o_wr_w;
    wire                            o_rd_r;

    // Register decoding signals
    wire                            wr_reg0, wr_reg1, wr_reg2, wr_reg3, wr_reg5;
    wire                            rd_reg4;
    wire [31:0]                     rd_ospi_reg4;

    // CPU FIFO Interface connections
    wire                            cpu_full;
    wire                            cpu_empty;
    wire [7:0]                      cpu_rdata;
    
    // DMAC Outputs
    wire                            dmac_start;
    wire [47:0]                     dmac_cmd_addr;
    wire [7:0]                      dmac_burst_len;
    wire [3:0]                      dmac_latency;
    wire [3:0]                      dmac_recovery;
    wire [1:0]                      dmac_capture_shmoo;

    // HyperBus Master Output Status
    wire                            master_start_rdy;
    wire                            wr_read_fifo;
    wire                            tlast_read_fifo;
    wire                            tlast_write_fifo;

    // MUX Intermediate signals
    wire                            mode_accel;
    wire [47:0]                     final_cmd_addr;
    wire                            final_start;
    wire [7:0]                      final_burst_len;
    wire [3:0]                      final_latency;
    wire [3:0]                      final_recovery;
    wire [1:0]                      final_capture_shmoo;
    wire                            dmac_start_rdy;

    // ========================================================
    // CPU REGISTERS BLOCK
    // ========================================================
    reg [31:0] wr_ospi_reg0, wr_ospi_reg1, wr_ospi_reg2, wr_ospi_reg3, wr_ospi_reg5;
    reg [31:0] rdata_mux;

    always @(posedge clk, negedge resetn) begin
        if(~resetn) begin
            wr_ospi_reg0 <= 0;
            wr_ospi_reg1 <= 0;
            wr_ospi_reg2 <= 0;
            wr_ospi_reg3 <= 0;
            wr_ospi_reg5 <= 0; // Default 0 = CPU Mode
        end
        else begin
            if (wr_reg0) wr_ospi_reg0 <= o_data_w;
            if (wr_reg1) wr_ospi_reg1 <= o_data_w;
            if (wr_reg2) wr_ospi_reg2 <= o_data_w;
            if (wr_reg3) wr_ospi_reg3 <= o_data_w;
            if (wr_reg5) wr_ospi_reg5 <= o_data_w;
        end
    end

    // Address Decoding
    assign wr_reg0 = (o_wr_w && (o_addr_w == ADDR_REGISTERS_0)) ? 1'b1 : 1'b0;
    assign wr_reg1 = (o_wr_w && (o_addr_w == ADDR_REGISTERS_1)) ? 1'b1 : 1'b0;
    assign wr_reg2 = (o_wr_w && (o_addr_w == ADDR_REGISTERS_2)) ? 1'b1 : 1'b0;
    assign wr_reg3 = (o_wr_w && (o_addr_w == ADDR_REGISTERS_3)) ? 1'b1 : 1'b0;
    assign wr_reg5 = (o_wr_w && (o_addr_w == ADDR_REGISTERS_5)) ? 1'b1 : 1'b0;
    assign rd_reg4 = (o_rd_r && (o_addr_r == ADDR_REGISTERS_4)) ? 1'b1 : 1'b0;

    // Read Data Multiplexer
    always @(*) begin
        case (o_addr_r)
            ADDR_REGISTERS_0: rdata_mux = wr_ospi_reg0;
            ADDR_REGISTERS_1: rdata_mux = wr_ospi_reg1;
            ADDR_REGISTERS_2: rdata_mux = wr_ospi_reg2;
            ADDR_REGISTERS_3: rdata_mux = wr_ospi_reg3;
            ADDR_REGISTERS_4: rdata_mux = rd_ospi_reg4;
            ADDR_REGISTERS_5: rdata_mux = wr_ospi_reg5;
            default:          rdata_mux = 32'h0;
        endcase
    end
    
    assign i_data_r = rdata_mux;

    // Map Read Status (Register 4)
    assign rd_ospi_reg4[7:0]   = cpu_rdata;
    assign rd_ospi_reg4[8]     = cpu_full;
    assign rd_ospi_reg4[9]     = cpu_empty;
    assign rd_ospi_reg4[10]    = master_start_rdy;
    assign rd_ospi_reg4[31:11] = 21'd0;

    // ========================================================
    // MULTIPLEXER (MUX) FOR COMMAND ROUTING
    // ========================================================
    // mode_accel = 0 -> Controlled by CPU via OSPI Registers
    // mode_accel = 1 -> Controlled by DMAC Accel core
    assign mode_accel          = wr_ospi_reg5[0];

    assign final_cmd_addr      = mode_accel ? dmac_cmd_addr      : {wr_ospi_reg0[15:0], wr_ospi_reg1};
    assign final_start         = mode_accel ? dmac_start         : wr_ospi_reg3[10];
    
    assign final_burst_len     = mode_accel ? dmac_burst_len     : wr_ospi_reg2[4:0];
    assign final_latency       = mode_accel ? dmac_latency       : wr_ospi_reg2[8:5];
    assign final_recovery      = mode_accel ? dmac_recovery      : wr_ospi_reg2[12:9];
    assign final_capture_shmoo = mode_accel ? dmac_capture_shmoo : wr_ospi_reg2[14:13];

    // Give ready signal back to DMAC only if Accel mode is enabled
    assign dmac_start_rdy      = mode_accel ? master_start_rdy   : 1'b0;

    // ========================================================
    // MODULE: DMAC (Accelerator Command Generator)
    // ========================================================
    dmac_peri2accel #(
        .NUM_MASTERS        (2),
        .ADDR_WIDTH         (ADDR_WIDTH_DMAC),
        .BURST_WIDTH        (BURST_WIDTH)
    ) coordinator_center_dmac (
        .clk_i              (clk),
        .resetn_i           (resetn),
        
        .start_o            (dmac_start),
        .start_ready_i      (dmac_start_rdy),
        .cmd_addr_o         (dmac_cmd_addr),
        .burst_len_o        (dmac_burst_len),
        .latency_o          (dmac_latency),
        .recovery_o         (dmac_recovery),
        .capture_shmoo_o    (dmac_capture_shmoo),
        
        .wr_read_fifo_i     (wr_read_fifo),
        .tlast_read_fifo_o  (tlast_read_fifo),
        .tlast_write_fifo_i (tlast_write_fifo),
        
        .AWVALID_i          (AWVALID_i),
        .AWREADY_o          (AWREADY_o),
        .AWADDR_i           (AWADDR_i),
        .AWBURST_i          (AWBURST_i),
        .ARVALID_i          (ARVALID_i),
        .ARREADY_o          (ARREADY_o),
        .ARADDR_i           (ARADDR_i),
        .ARBURST_i          (ARBURST_i),
        .weight_write_channel_i     (wr_ospi_reg5[16:2]),   // Example weight for write channel
        .weight_read_channel_i      (wr_ospi_reg5[31:17])    // Example weight for read channel
    );

    // ========================================================
    // MODULE: HYPERBUS MASTER (4-Port Multiplexed Core)
    // ========================================================
    hyperbus_master #(
        .W_BURSTLEN         (8),
        .ADDR_WIDTH_FIFO    (8),
        .DATA_WIDTH_FIFO    (8),
        .DATA_WIDTH_BYTE    (DATA_WIDTH_BYTE)
    ) u_hyperbus_master (
        // System Config
        .clk                (clk),               
        .rst_n              (resetn),             
        .mode_sel           (mode_accel),  // Passed from register 5

        // Shared Control Signals
        .cmd_addr           (final_cmd_addr),          
        .start              (final_start),             
        .start_rdy          (master_start_rdy),         
        .burst_len          (final_burst_len),         
        .latency            (final_latency),           
        .recovery           (final_recovery),          
        .capture_shmoo      (final_capture_shmoo),     

        // CPU Port (Basic FIFO) - Connected to Registers
        .wdata_cpu_i        (wr_ospi_reg3[7:0]),
        .wr_cpu_i           (wr_ospi_reg3[8]),
        .full_cpu_o         (cpu_full),
        
        .rdata_cpu_o        (cpu_rdata),
        .rd_cpu_i           (wr_ospi_reg3[9]),
        .empty_cpu_o        (cpu_empty),

        // Accel Port (AXI-STREAM Master)
        .m_tvalid_o         (m_tvalid_o),        
        .m_tready_i         (m_tready_i),        
        .m_tdata_o          (m_tdata_o),         
        .m_tstrb_o          (m_tstrb_o),         
        .m_tkeep_o          (m_tkeep_o),         
        .m_tlast_o          (m_tlast_o),         

        // Accel Port (AXI-STREAM Slave)
        .s_tvalid_i         (s_tvalid_i),        
        .s_tready_o         (s_tready_o),        
        .s_tdata_i          (s_tdata_i),         
        .s_tstrb_i          (s_tstrb_i),         
        .s_tkeep_i          (s_tkeep_i),         
        .s_tlast_i          (s_tlast_i),         

        // Physical HyperBus Interface
        .dq_io              (dq_io),             
        .rwds_io            (rwds_io),           
        .hclk_p             (hclk_p),            
        .hclk_n             (hclk_n),            
        .cs_n               (cs_n),              

        // Internal Status FIFO (Connected between DMAC & Core)
        .wr_read_fifo_o     (wr_read_fifo),    
        .tlast_read_fifo_i  (tlast_read_fifo), 
        .tlast_write_fifo_o (tlast_write_fifo) 
    );

    // ========================================================
    // MODULE: AXI-LITE SLAVE INTERFACE
    // ========================================================
    axi_lite_slave_interface #(
        .ADDR_WIDTH         (ADDR_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .TRANS_W_STRB_W     (TRANS_W_STRB_W),
        .TRANS_WR_RESP_W    (TRANS_WR_RESP_W),
        .TRANS_PROT         (TRANS_PROT),
        .CYCLE_CLOCK        (CYCLE_CLOCK),
        .NUM_MASTERS        (NUM_MASTERS)
    ) ospi_axi_lite_interface (
        .clk_i              (clk),
        .resetn_i           (resetn),

        .i_axi_awaddr       (i_axi_awaddr),
        .i_axi_awvalid      (i_axi_awvalid),
        .o_axi_awready      (o_axi_awready),
        .i_axi_awprot       (i_axi_awprot),

        .i_axi_wdata        (i_axi_wdata),
        .i_axi_wstrb        (i_axi_wstrb),
        .i_axi_wvalid       (i_axi_wvalid),
        .o_axi_wready       (o_axi_wready),

        .o_axi_bresp        (o_axi_bresp),
        .o_axi_bvalid       (o_axi_bvalid),
        .i_axi_bready       (i_axi_bready),

        .i_axi_araddr       (i_axi_araddr),
        .i_axi_arvalid      (i_axi_arvalid),
        .o_axi_arready      (o_axi_arready),
        .i_axi_arprot       (i_axi_arprot),

        .o_axi_rdata        (o_axi_rdata),
        .o_axi_rvalid       (o_axi_rvalid),
        .o_axi_rresp        (o_axi_rresp),
        .i_axi_rready       (i_axi_rready),

        .o_addr_w           (o_addr_w),
        .o_awprot_w         (),

        .o_wen              (),       
        .o_data_w           (o_data_w),
        .o_write_data_w     (o_wr_w),

        .i_bresp_w          (2'b00),

        .o_addr_r           (o_addr_r),
        .o_arprot_r         (),
        
        .i_data_r           (i_data_r),
        .i_rresp_r          (2'b00),
        .o_read_data_r      (o_rd_r)
    );

endmodule