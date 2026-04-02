// `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026 09:03:48 PM
// Design Name: 
// Module Name: tb_OSPI_axi_lite_core
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

`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026
// Design Name: 
// Module Name: tb_OSPI_axi_lite_core
// Description: Testbench cho OSPI_axi_lite_core ho tro ca 2 mode (AXI-Lite va Accel AXIS)
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2026
// Design Name: 
// Module Name: tb_OSPI_axi_lite_core
// Description: Testbench ho tro AXI-Lite tuan tu (Strict Sequential: AW -> W -> B)
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_OSPI_axi_lite_core();

    // =========================================
    // 1. Parameters
    // =========================================
    parameter ADDR_WIDTH      = 32;
    parameter DATA_WIDTH      = 32;
    parameter TRANS_W_STRB_W  = 4;
    parameter TRANS_WR_RESP_W = 2;
    parameter TRANS_PROT      = 3;
    
    parameter ADDR_WIDTH_DMAC = 24;
    parameter BURST_WIDTH     = 8;
    parameter DATA_WIDTH_BYTE = 1;

    // Register Addresses
    localparam REG_0_CMD_HI   = 32'h0200_5000;
    localparam REG_1_CMD_LO   = 32'h0200_5004;
    localparam REG_2_CONFIG   = 32'h0200_5008;
    localparam REG_3_CTRL_WR  = 32'h0200_500C;
    localparam REG_4_STATUS   = 32'h0200_5010;
    localparam REG_5_MODE     = 32'h0200_5014;

    // =========================================
    // 2. Signals
    // =========================================
    reg clk;
    reg resetn;

    // -----------------------------------------
    // KÊNH GHI (WRITE CHANNELS)
    // -----------------------------------------
    reg  [ADDR_WIDTH-1:0]      i_axi_awaddr;
    reg                        i_axi_awvalid;
    wire                       o_axi_awready;
    reg  [TRANS_PROT-1:0]      i_axi_awprot;

    reg  [DATA_WIDTH-1:0]      i_axi_wdata;
    reg  [TRANS_W_STRB_W-1:0]  i_axi_wstrb;
    reg                        i_axi_wvalid;
    wire                       o_axi_wready;

    wire [TRANS_WR_RESP_W-1:0] o_axi_bresp;
    wire                       o_axi_bvalid;
    reg                        i_axi_bready;

    // -----------------------------------------
    // KÊNH ĐỌC (READ CHANNELS)
    // -----------------------------------------
    reg  [ADDR_WIDTH-1:0]      i_axi_araddr;
    reg                        i_axi_arvalid;
    wire                       o_axi_arready;
    reg  [TRANS_PROT-1:0]      i_axi_arprot;

    wire [DATA_WIDTH-1:0]      o_axi_rdata;
    wire                       o_axi_rvalid;
    wire [TRANS_WR_RESP_W-1:0] o_axi_rresp;
    reg                        i_axi_rready;

    // -----------------------------------------
    // ACCEL PORTS & HYPERBUS
    // -----------------------------------------
    reg                        AWVALID_i;
    wire                       AWREADY_o;
    reg  [ADDR_WIDTH_DMAC-1:0] AWADDR_i;
    reg  [BURST_WIDTH-1:0]     AWBURST_i;

    reg                        ARVALID_i;
    wire                       ARREADY_o;
    reg  [ADDR_WIDTH_DMAC-1:0] ARADDR_i;
    reg  [BURST_WIDTH-1:0]     ARBURST_i;

    wire                          m_tvalid_o;
    reg                           m_tready_i;
    wire  [DATA_WIDTH_BYTE*8-1:0] m_tdata_o;
    wire  [DATA_WIDTH_BYTE-1:0]   m_tstrb_o;
    wire  [DATA_WIDTH_BYTE-1:0]   m_tkeep_o;
    wire                          m_tlast_o;

    reg                           s_tvalid_i;
    wire                          s_tready_o;
    reg   [DATA_WIDTH_BYTE*8-1:0] s_tdata_i;
    reg   [DATA_WIDTH_BYTE-1:0]   s_tstrb_i;
    reg   [DATA_WIDTH_BYTE-1:0]   s_tkeep_i;
    reg                           s_tlast_i;

    wire [7:0] dq_io;
    wire       rwds_io;
    wire       hclk_p;
    wire       hclk_n;
    wire       cs_n;

    // =========================================
    // 3. Instantiate DUT
    // =========================================
    OSPI_axi_lite_core #(
        .ADDR_WIDTH         (ADDR_WIDTH),
        .DATA_WIDTH         (DATA_WIDTH),
        .ADDR_WIDTH_DMAC    (ADDR_WIDTH_DMAC),
        .BURST_WIDTH        (BURST_WIDTH),
        .DATA_WIDTH_BYTE    (DATA_WIDTH_BYTE)
    ) uut (
        .clk                (clk), 
        .resetn             (resetn),

        .i_axi_awaddr       (i_axi_awaddr), .i_axi_awvalid(i_axi_awvalid), .o_axi_awready(o_axi_awready), .i_axi_awprot(i_axi_awprot),
        .i_axi_wdata        (i_axi_wdata),  .i_axi_wstrb(i_axi_wstrb),     .i_axi_wvalid(i_axi_wvalid),   .o_axi_wready(o_axi_wready),
        .o_axi_bresp        (o_axi_bresp),  .o_axi_bvalid(o_axi_bvalid),   .i_axi_bready(i_axi_bready),
        
        .i_axi_araddr       (i_axi_araddr), .i_axi_arvalid(i_axi_arvalid), .o_axi_arready(o_axi_arready), .i_axi_arprot(i_axi_arprot),
        .o_axi_rdata        (o_axi_rdata),  .o_axi_rvalid(o_axi_rvalid),   .o_axi_rresp(o_axi_rresp),     .i_axi_rready(i_axi_rready),

        .AWVALID_i          (AWVALID_i), .AWREADY_o(AWREADY_o), .AWADDR_i(AWADDR_i), .AWBURST_i(AWBURST_i),
        .ARVALID_i          (ARVALID_i), .ARREADY_o(ARREADY_o), .ARADDR_i(ARADDR_i), .ARBURST_i(ARBURST_i),

        .m_tvalid_o         (m_tvalid_o), .m_tready_i(m_tready_i), .m_tdata_o(m_tdata_o), .m_tstrb_o(m_tstrb_o), .m_tkeep_o(m_tkeep_o), .m_tlast_o(m_tlast_o),
        .s_tvalid_i         (s_tvalid_i), .s_tready_o(s_tready_o), .s_tdata_i(s_tdata_i), .s_tstrb_i(s_tstrb_i), .s_tkeep_i(s_tkeep_i), .s_tlast_i(s_tlast_i),

        .dq_io              (dq_io), .rwds_io(rwds_io), .hclk_p(hclk_p), .hclk_n(hclk_n), .cs_n(cs_n)
    );

    // =========================================
    // 4. Instantiate HyperRAM Model
    // =========================================
    s27kl0641 #(
        .UserPreload        (0),
        .TimingModel        ("S27KL0641DABHI100")
    ) hyper_ram_chip  (
        .DQ7(dq_io[7]), .DQ6(dq_io[6]), .DQ5(dq_io[5]), .DQ4(dq_io[4]),
        .DQ3(dq_io[3]), .DQ2(dq_io[2]), .DQ1(dq_io[1]), .DQ0(dq_io[0]),
        .RWDS(rwds_io), .CSNeg(cs_n), .CK(hclk_p), .RESETNeg(resetn)
    );

    // =========================================
    // 5. Clock Generation (100MHz = 10ns = 10000ps)
    // =========================================
    initial begin
        clk = 0;
        forever #5000 clk = ~clk; 
    end

    // =========================================
    // 6. TASKS AXI-LITE (TUẦN TỰ TUYỆT ĐỐI)
    // =========================================
    task axi_lite_write(input [31:0] addr, input [31:0] data);
        begin
            // -----------------------------------------
            // BƯỚC 1: KÊNH AW (ĐỊA CHỈ GHI)
            // -----------------------------------------
            @(posedge clk); #1;
            i_axi_awaddr  = addr;
            i_axi_awprot  = 3'b000;
            i_axi_awvalid = 1'b1;
            
            // Đợi module phản hồi AWREADY
            wait(o_axi_awready == 1'b1);
            @(posedge clk); #1;
            i_axi_awvalid = 1'b0; // AWVALID LOW
            
            // -----------------------------------------
            // BƯỚC 2: KÊNH W (DỮ LIỆU GHI)
            // -----------------------------------------
            i_axi_wdata   = data;
            i_axi_wstrb   = 4'hF;
            i_axi_wvalid  = 1'b1; // WVALID HIGH

            // Đợi module phản hồi WREADY
            wait(o_axi_wready == 1'b1);
            @(posedge clk); #1;
            i_axi_wvalid  = 1'b0; // WVALID LOW

            // -----------------------------------------
            // BƯỚC 3: KÊNH B (PHẢN HỒI GHI)
            // -----------------------------------------
            i_axi_bready  = 1'b1; // BREADY HIGH

            // Đợi module phản hồi BVALID
            wait(o_axi_bvalid == 1'b1);
            @(posedge clk); #1;
            i_axi_bready  = 1'b0; // BREADY LOW
            
            $display("[%0t] CPU WRITE: Addr = %h, Data = %h", $time, addr, data);
        end
    endtask

    task axi_lite_read(input [31:0] addr, output [31:0] data);
        begin
            // -----------------------------------------
            // BƯỚC 1: KÊNH AR (ĐỊA CHỈ ĐỌC)
            // -----------------------------------------
            @(posedge clk); #1;
            i_axi_araddr  = addr;
            i_axi_arprot  = 3'b000;
            i_axi_arvalid = 1'b1;

            // Đợi module phản hồi ARREADY
            wait(o_axi_arready == 1'b1);
            @(posedge clk); #1;
            i_axi_arvalid = 1'b0; // ARVALID LOW

            // -----------------------------------------
            // BƯỚC 2: KÊNH R (DỮ LIỆU ĐỌC)
            // -----------------------------------------
            i_axi_rready  = 1'b1; // RREADY HIGH

            // Đợi module phản hồi RVALID và trả Data
            wait(o_axi_rvalid == 1'b1);
            data = o_axi_rdata;
            
            @(posedge clk); #1;
            i_axi_rready  = 1'b0; // RREADY LOW
            
            $display("[%0t] CPU READ:  Addr = %h, Data = %h", $time, addr, data);
        end
    endtask

    // =========================================
    // 7. KỊCH BẢN MÔ PHỎNG (TEST SCENARIO)
    // =========================================
    integer i;
    reg [31:0] read_val;

    initial begin
        // Reset Init
        resetn = 0;
        
        i_axi_awaddr = 0; i_axi_awvalid = 0; i_axi_awprot = 0;
        i_axi_wdata = 0; i_axi_wstrb = 0; i_axi_wvalid = 0;
        i_axi_bready = 0;
        i_axi_araddr = 0; i_axi_arvalid = 0; i_axi_arprot = 0;
        i_axi_rready = 0; 
        
        AWVALID_i = 0; AWADDR_i = 0; AWBURST_i = 0;
        ARVALID_i = 0; ARADDR_i = 0; ARBURST_i = 0;
        m_tready_i = 0; s_tvalid_i = 0; s_tdata_i = 0; s_tstrb_i = 0; s_tkeep_i = 0; s_tlast_i = 0;

        #25000;
        resetn = 1;
        
        $display("[%0t] Dang cho HyperRAM power-up (150us)...", $time);
        #300000000; 
        $display("[%0t] HyperRAM da san sang!", $time);

        // ============================================================
        // TEST CASE 1: CPU MODE (mode_sel = 0)
        // ============================================================
        $display("\n[%0t] --- BAT DAU TEST CASE 1: CPU MODE ---", $time);
        
        // 1. Cấu hình mode = 0 (CPU)
        axi_lite_write(REG_5_MODE, 32'h0);
        
        // 2. Cấu hình Latency = 6, Recovery = 0, Burst = 2, Shmoo = 2
        //    ==> Giá trị HEX tương ứng là 0x40C2
        axi_lite_write(REG_2_CONFIG, 32'h0000_40C2); 
        
        // ------------------------------------------------------------
        // GIAI ĐOẠN 1: GHI DỮ LIỆU TỪ CPU XUỐNG RAM
        // ------------------------------------------------------------
        $display("\n[%0t] [CPU WRITE] 1. Day 4 Byte vao FIFO Ghi...", $time);
        // Bit [7:0]=Data, Bit[8]=wr_i (Xung ghi)
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0111); axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000); 
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0122); axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000); 
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0133); axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000); 
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0144); axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000); 
        
        $display("[%0t] [CPU WRITE] 2. Set dia chi va Kich hoat HyperBus...", $time);
        // Set Command Address: 0x123400
        axi_lite_write(REG_1_CMD_LO, 32'h3400_0000); 
        axi_lite_write(REG_0_CMD_HI, 32'h0000_0012); 
        
        // Kích xung START (Bit 10 = 1)
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0400);
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000);
        
        #500000;
        
        // ------------------------------------------------------------
        // GIAI ĐOẠN 2: CPU ĐỌC DỮ LIỆU TỪ RAM VỀ
        // ------------------------------------------------------------
        $display("\n[%0t] [CPU READ] 1. Kich hoat HyperBus keo data tu RAM ve FIFO...", $time);
        // Set Command Address: 0x123400 (Dùng Bit 47=1 cho lệnh Read)
        axi_lite_write(REG_1_CMD_LO, 32'h3400_0000); 
        axi_lite_write(REG_0_CMD_HI, 32'h0000_8012); 
        
        // Kích xung START đọc (Bit 10 = 1)
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0400); 
        axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000); 
        
        $display("[%0t] Dang cho RAM do du lieu vao CPU FIFO...", $time);
        #500000; 
        
        $display("\n[%0t] [CPU READ] 2. CPU tien hanh doc 4 byte tu FIFO:", $time);
        for (i = 1; i <= 4; i = i + 1) begin
            // Đọc thanh ghi REG_4_STATUS để lấy giá trị đỉnh FIFO 
            axi_lite_read(REG_4_STATUS, read_val);
            $display("  -> [%0t] CPU Doc duoc Byte %0d: 8'h%h", $time, i, read_val[7:0]);

            // Kích xung rd_cpu_i (Bit 9 = 1) để pop data đi
            axi_lite_write(REG_3_CTRL_WR, 32'h0000_0200); 
            axi_lite_write(REG_3_CTRL_WR, 32'h0000_0000); 
        end

        // ============================================================
        // TEST CASE 2: ACCEL MODE (mode_sel = 1)
        // ============================================================
        $display("\n[%0t] --- CHUYEN SANG TEST CASE 2: ACCEL MODE ---", $time);
        
        // 1. Chuyển quyền điều khiển cho Accel qua thanh ghi cấu hình (REG_5)
        axi_lite_write(REG_5_MODE, 32'h1);
        #50000;

        $display("\n[%0t] --- BAT DAU TEST CASE GHI DU LIEU TREN ACCEL ---", $time);
        
        AWADDR_i  = 24'h123400;
        AWBURST_i = 8'd4; 
        AWVALID_i = 1;

        wait (AWREADY_o == 1'b1);
        @(posedge clk);
        #1; 
        AWVALID_i = 0; 
        
        $display("[%0t] Bat dau day data vao AXIS Slave...", $time);
        
        for (i = 1; i <= 4; i = i + 1) begin
            s_tvalid_i = 1;
            case (i)
                1: s_tdata_i = 8'hAA;
                2: s_tdata_i = 8'hBB;
                3: s_tdata_i = 8'hCC;
                4: s_tdata_i = 8'hDD;
            endcase
            s_tstrb_i  = 1'b1;
            s_tkeep_i  = 1'b1;
            s_tlast_i  = (i == 4) ? 1'b1 : 1'b0; 
            
            wait (s_tready_o == 1'b1);
            @(posedge clk);
            #1;  
        end
        
        s_tvalid_i = 0;
        s_tlast_i  = 0;
        $display("[%0t] Da day xong du lieu. Cho Hyperbus Master ghi vao chip...", $time);

        #500000; 

        $display("\n[%0t] --- BAT DAU TEST CASE DOC DU LIEU TREN ACCEL ---", $time);
        
        m_tready_i = 1;

        ARADDR_i  = 24'h123400;
        ARBURST_i = 8'd4; 
        ARVALID_i = 1;

        wait (ARREADY_o == 1'b1);
        @(posedge clk);
        #1; 
        ARVALID_i = 0; 
        
        $display("[%0t] Yeu cau Doc da gui. Dang cho chip RAM phan hoi...", $time);

        for (i = 1; i <= 4; i = i + 1) begin
            @(posedge clk);
            while (m_tvalid_o !== 1'b1) begin
                @(posedge clk);
            end
            $display("[%0t] Doc duoc Byte %0d: 8'h%h", $time, i, m_tdata_o);
        end

        m_tready_i = 0;
        $display("[%0t] Hoan tat viec doc tren Accel!", $time);

        // =========================================
        // KẾT THÚC MÔ PHỎNG
        // =========================================
        #100000;
        $display("\n[%0t] --- KET THUC TESTBENCH ---", $time);
        $finish;
    end

endmodule