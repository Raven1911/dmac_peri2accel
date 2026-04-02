// `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 09:56:39 PM
// Design Name: 
// Module Name: tb_dmac_peri2accel_top
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
module tb_dmac_peri2accel_top();

    // =========================================
    // 1. Khai báo Parameters
    // =========================================
    parameter NUM_MASTERS = 2;
    parameter ADDR_WIDTH = 24;
    parameter BURST_WIDTH = 8;
    parameter DATA_WIDTH_BYTE = 1;

    // =========================================
    // 2. Khai báo Tín hiệu (Signals)
    // =========================================
    reg clk_i;
    reg resetn_i;

    // --- Cổng Accelerator (AW/AR Channels) ---
    reg                           AWVALID_i;
    wire                          AWREADY_o;
    reg       [ADDR_WIDTH-1:0]    AWADDR_i;
    reg       [BURST_WIDTH-1:0]   AWBURST_i;

    reg                           ARVALID_i;
    wire                          ARREADY_o;
    reg       [ADDR_WIDTH-1:0]    ARADDR_i;
    reg       [BURST_WIDTH-1:0]   ARBURST_i;

    // --- Cổng AXI-STREAM MASTER (Đọc Data ra) ---
    wire                          m_tvalid_o;
    reg                           m_tready_i;
    wire  [DATA_WIDTH_BYTE*8-1:0] m_tdata_o;
    wire  [DATA_WIDTH_BYTE-1:0]   m_tstrb_o;
    wire  [DATA_WIDTH_BYTE-1:0]   m_tkeep_o;
    wire                          m_tlast_o;

    // --- Cổng AXI-STREAM SLAVE (Ghi Data vào) ---
    reg                           s_tvalid_i;
    wire                          s_tready_o;
    reg   [DATA_WIDTH_BYTE*8-1:0] s_tdata_i;
    reg   [DATA_WIDTH_BYTE-1:0]   s_tstrb_i;
    reg   [DATA_WIDTH_BYTE-1:0]   s_tkeep_i;
    reg                           s_tlast_i;

    // --- Tín hiệu vật lý HyperBus ---
    wire  [7:0]                   dq_io;
    wire                          rwds_io;
    wire                          hclk_p;
    wire                          hclk_n;
    wire                          cs_n;

    // =========================================
    // 3. Khởi tạo Unit Under Test (UUT)
    // =========================================
    dmac_peri2accel_top #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_WIDTH(BURST_WIDTH),
        .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE)
    ) uut (
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        
        .AWVALID_i(AWVALID_i), .AWREADY_o(AWREADY_o),
        .AWADDR_i(AWADDR_i),   .AWBURST_i(AWBURST_i),
        
        .ARVALID_i(ARVALID_i), .ARREADY_o(ARREADY_o),
        .ARADDR_i(ARADDR_i),   .ARBURST_i(ARBURST_i),
        
        .m_tvalid_o(m_tvalid_o), .m_tready_i(m_tready_i),
        .m_tdata_o(m_tdata_o),   .m_tstrb_o(m_tstrb_o),
        .m_tkeep_o(m_tkeep_o),   .m_tlast_o(m_tlast_o),
        
        .s_tvalid_i(s_tvalid_i), .s_tready_o(s_tready_o),
        .s_tdata_i(s_tdata_i),   .s_tstrb_i(s_tstrb_i),
        .s_tkeep_i(s_tkeep_i),   .s_tlast_i(s_tlast_i),

        // HyperBus Physical Layer
        .dq_io(dq_io),
        .rwds_io(rwds_io),
        .hclk_p(hclk_p),
        .hclk_n(hclk_n),
        .cs_n(cs_n)
    );

    // =========================================
    // 4. Khởi tạo Mô hình Chip Nhớ HyperRAM
    // =========================================
    s27kl0641 #(
        .UserPreload(0),
        .TimingModel("S27KL0641DABHI100")
    )hyper_ram_chip  (
        .DQ7(dq_io[7]),
        .DQ6(dq_io[6]),
        .DQ5(dq_io[5]),
        .DQ4(dq_io[4]),
        .DQ3(dq_io[3]),
        .DQ2(dq_io[2]),
        .DQ1(dq_io[1]),
        .DQ0(dq_io[0]),
        .RWDS(rwds_io),
        .CSNeg(cs_n),
        .CK(hclk_p),           // Chip nhận positive clock từ hclk_p
        .RESETNeg(resetn_i)    // Nối chung với reset hệ thống
    );

    // =========================================
    // 5. Tạo xung Clock 100MHz (10ns)
    // =========================================
    initial begin
        clk_i = 0;
        forever #2500 clk_i = ~clk_i;
    end

    // =========================================
    // 6. Kịch bản Mô Phỏng (Test Scenario)
    // =========================================
    integer i;

    initial begin
        // Khởi tạo các tín hiệu
        resetn_i = 0;
        AWVALID_i = 0; AWADDR_i = 0; AWBURST_i = 0;
        ARVALID_i = 0; ARADDR_i = 0; ARBURST_i = 0;
        m_tready_i = 0;
        s_tvalid_i = 0; s_tdata_i = 0; s_tstrb_i = 0; s_tkeep_i = 0; s_tlast_i = 0;

        // Reset hệ thống (Giữ reset khoảng 25ns = 25000ps)
        #25000;
        resetn_i = 1;
        
        // CHỜ 150us CHO CHIP NHỚ POWER-UP THEO ĐÚNG DATASHEET
        // 150 us = 150,000 ns = 150,000,000 ps
        $display("[%0t] Dang cho chip HyperRAM khoi dong (150us)...", $time);
        #300000000; // Để dư 5us (155 triệu ps) cho chắc chắn
        $display("[%0t] HyperRAM da san sang!", $time);

        // ============================================================
        // TEST CASE 1: GHI DỮ LIỆU VÀO RAM QUA AXIS SLAVE
        // ============================================================
        $display("\n[%0t] --- BAT DAU TEST CASE 1: GHI DU LIEU ---", $time);
        
        // 1. Gửi lệnh Ghi 4 Bytes tới địa chỉ 0x123400
        AWADDR_i  = 24'h123400;
        AWBURST_i = 8'd4; 
        AWVALID_i = 1;

        // Chờ Arbiter cấp quyền (AWREADY = 1)
        wait (AWREADY_o == 1'b1);
        @(posedge clk_i);
        AWVALID_i = 0; 
        
        // 2. Bơm 4 byte dữ liệu (0xAA, 0xBB, 0xCC, 0xDD) vào AXIS Slave
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
            @(posedge clk_i);
            #1;  // <--- THÊM ĐÚNG 1 DÒNG NÀY ĐỂ FIX LỖI RACE CONDITION
        end
        
        s_tvalid_i = 0;
        s_tlast_i  = 0;
        $display("[%0t] Da day xong du lieu. Cho Hyperbus Master ghi vao chip...", $time);

        // Chờ Hyperbus xử lý xong quá trình ghi (Chờ 500ns = 500,000ps)
        #500000; 

        // Nếu bạn muốn bỏ comment phần TEST CASE 2 (Đọc), nhớ đổi các #delay trong đó 
        // (ví dụ #100 thành #100000) nhé!

    
        // ============================================================
        // TEST CASE 2: ĐỌC NGƯỢC LẠI DỮ LIỆU QUA AXIS MASTER
        // ============================================================
        $display("\n[%0t] --- BAT DAU TEST CASE 2: DOC DU LIEU ---", $time);
        
        // Bật sẵn m_tready_i để đón dữ liệu trả về từ RAM
        m_tready_i = 1;

        // 1. Gửi lệnh Đọc 4 Bytes từ chính địa chỉ 0x123400
        ARADDR_i  = 24'h123400;
        ARBURST_i = 8'd4; 
        ARVALID_i = 1;

        // Chờ Arbiter cấp quyền (ARREADY = 1)
        wait (ARREADY_o == 1'b1);
        @(posedge clk_i);
        ARVALID_i = 0; 
        
        $display("[%0t] Yeu cau Doc da gui. Dang cho chip RAM phan hoi...", $time);

        // 2. Chờ dữ liệu văng ra từ cổng m_tvalid_o và in kết quả
        for (i = 1; i <= 4; i = i + 1) begin
            // Đợi đến khi sườn lên của clock có m_tvalid_o = 1
            @(posedge clk_i);
            while (m_tvalid_o !== 1'b1) begin
                @(posedge clk_i);
            end
            
            // In ra dữ liệu bắt được
            $display("[%0t] Doc duoc Byte %0d: 8'h%h", $time, i, m_tdata_o);
        end

        // Tắt cờ ready sau khi nhận đủ
        m_tready_i = 0;
        $display("[%0t] Hoan tat viec doc!", $time);

        // =========================================
        // KẾT THÚC MÔ PHỎNG
        // =========================================
        // Chờ 20 chu kỳ clock (20 * 5000ps) để hệ thống xả FSM về IDLE hoàn toàn
        #100000;
        $display("\n[%0t] --- KET THUC TESTBENCH ---", $time);
        $finish;
    end

endmodule
