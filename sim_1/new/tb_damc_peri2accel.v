`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 08:32:12 PM
// Design Name: 
// Module Name: tb_damc_peri2accel
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


`timescale 1ns / 1ps

module tb_damc_peri2accel();

    // Tham số cấu hình
    parameter NUM_MASTERS = 2;
    parameter ADDR_WIDTH = 24;
    parameter BURST_WIDTH = 8;

    // Tín hiệu Input
    reg clk_i;
    reg resetn_i;
    reg start_ready_i;
    reg wr_read_fifo_i;
    reg tlast_write_fifo_i;
    reg AWVALID_i;
    reg [ADDR_WIDTH-1:0] AWADDR_i;
    reg [BURST_WIDTH-1:0] AWBURST_i;
    reg ARVALID_i;
    reg [ADDR_WIDTH-1:0] ARADDR_i;
    reg [BURST_WIDTH-1:0] ARBURST_i;

    // Tín hiệu Output
    wire start_o;
    wire [47:0] cmd_addr_o;
    wire [7:0] burst_len_o;
    wire [3:0] latency_o;
    wire [3:0] recovery_o;
    wire [1:0] capture_shmoo_o;
    wire tlast_read_fifo_o;
    wire AWREADY_o;
    wire ARREADY_o;

    // Khởi tạo Module Top (Unit Under Test - UUT)
    damc_peri2accel #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_WIDTH(BURST_WIDTH)
    ) uut (
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .start_o(start_o),
        .start_ready_i(start_ready_i),
        .cmd_addr_o(cmd_addr_o),
        .burst_len_o(burst_len_o),
        .latency_o(latency_o),
        .recovery_o(recovery_o),
        .capture_shmoo_o(capture_shmoo_o),
        .wr_read_fifo_i(wr_read_fifo_i),
        .tlast_read_fifo_o(tlast_read_fifo_o),
        .tlast_write_fifo_i(tlast_write_fifo_i),
        .AWVALID_i(AWVALID_i),
        .AWREADY_o(AWREADY_o),
        .AWADDR_i(AWADDR_i),
        .AWBURST_i(AWBURST_i),
        .ARVALID_i(ARVALID_i),
        .ARREADY_o(ARREADY_o),
        .ARADDR_i(ARADDR_i),
        .ARBURST_i(ARBURST_i)
    );

    // Tạo xung Clock 100MHz (Chu kỳ 10ns)
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    // Biến cho vòng lặp giả lập FIFO
    integer i;

    // Khối giả lập Kịch bản Test (Test Scenarios)
    initial begin
        // 1. Khởi tạo tất cả tín hiệu ngõ vào
        resetn_i = 0;
        start_ready_i = 0;
        wr_read_fifo_i = 0;
        tlast_write_fifo_i = 0;
        
        AWVALID_i = 0;
        AWADDR_i = 24'h0;
        AWBURST_i = 8'h0;
        
        ARVALID_i = 0;
        ARADDR_i = 24'h0;
        ARBURST_i = 8'h0;

        // 2. Nhả Reset và bật cờ sẵn sàng từ Hyperbus
        #25;
        resetn_i = 1;
        #10;
        start_ready_i = 1; // Hệ thống Hyperbus master đã khởi động xong

        // ==========================================
        // TEST CASE 1: THỰC HIỆN LỆNH READ ĐƠN LẺ
        // ==========================================
        $display("[%0t] --- START TEST CASE 1: READ ---", $time);
        ARADDR_i = 24'h100000;
        ARBURST_i = 8'd10; // Đọc 10 byte (Burst = 5 words)
        ARVALID_i = 1'b1;  // Đẩy tín hiệu cấp quyền đọc
        
        // Chờ kênh Read được Arbiter cấp quyền và phản hồi ARREADY = 1
        wait (ARREADY_o == 1'b1);
        @(posedge clk_i);
        ARVALID_i = 1'b0; // Hạ Valid xuống sau khi bắt tay (handshake) thành công
        $display("[%0t] Read Handshake thanh cong! FSM bat dau doc.", $time);

        // Giả lập FIFO nhận dữ liệu đọc về để tlast_read_fifo_o nảy lên 1
        #40;
        $display("[%0t] Bom xung Data vao Read FIFO...", $time);
        for (i = 0; i < 10; i = i + 1) begin
            wr_read_fifo_i = 1;
            #10;
            wr_read_fifo_i = 0;
            if (tlast_read_fifo_o) $display("[%0t] --> tlast_read_fifo_o kich hoat o byte %0d!", $time, i+1);
        end
        #20;


        // ==========================================
        // TEST CASE 2: THỰC HIỆN LỆNH WRITE ĐƠN LẺ
        // ==========================================
        $display("[%0t] --- START TEST CASE 2: WRITE ---", $time);
        AWADDR_i = 24'h200000;
        AWBURST_i = 8'd20; // Ghi 20 byte (Burst = 10 words)
        AWVALID_i = 1'b1;
        
        wait (AWREADY_o == 1'b1);
        @(posedge clk_i);
        AWVALID_i = 1'b0;
        $display("[%0t] Write Handshake thanh cong!", $time);

        // FSM sẽ chạy qua các state, chờ đợi xả FIFO.
        // Cấp tlast_write_fifo_i để giải phóng FSM về IDLE
        #80; 
        tlast_write_fifo_i = 1'b1;
        #10;
        tlast_write_fifo_i = 1'b0;
        $display("[%0t] Da hoan tat day Write FIFO (tlast_write_fifo_i).", $time);
        #30;


        // ==========================================
        // TEST CASE 3: ARBITER CONTENTION (READ VÀ WRITE XẢY RA CÙNG LÚC)
        // ==========================================
        $display("[%0t] --- START TEST CASE 3: ARBITER CONTENTION ---", $time);
        // Đẩy 2 yêu cầu cùng lúc để xem module Arbiter ưu tiên ai trước
        AWADDR_i = 24'h333333; AWBURST_i = 8'd8;
        ARADDR_i = 24'h444444; ARBURST_i = 8'd6;
        AWVALID_i = 1'b1;
        ARVALID_i = 1'b1;

        // --- Giải quyết giao dịch thứ 1 ---
        // Đợi 1 trong 2 cái Ready bật lên
        wait (AWREADY_o == 1'b1 || ARREADY_o == 1'b1);
        @(posedge clk_i);
        if (AWREADY_o) begin
            $display("[%0t] ARBITER uu tien WRITE truoc!", $time);
            AWVALID_i = 1'b0; // Tắt Write Valid
            
            // Xả Write
            #80 tlast_write_fifo_i = 1'b1; #10 tlast_write_fifo_i = 1'b0;
            
            // Đợi FSM quay về IDLE và giải quyết nốt cái Read còn kẹt
            wait (ARREADY_o == 1'b1);
            @(posedge clk_i);
            $display("[%0t] ARBITER tiep tuc xu ly READ bi ket!", $time);
            ARVALID_i = 1'b0;
            // Xả Read
            #30 for(i=0; i<6; i=i+1) begin wr_read_fifo_i = 1; #10; wr_read_fifo_i = 0; end
        end else if (ARREADY_o) begin
            $display("[%0t] ARBITER uu tien READ truoc!", $time);
            ARVALID_i = 1'b0; // Tắt Read Valid
            
            // Xả Read
            #30 for(i=0; i<6; i=i+1) begin wr_read_fifo_i = 1; #10; wr_read_fifo_i = 0; end
            
            // Đợi giải quyết Write
            wait (AWREADY_o == 1'b1);
            @(posedge clk_i);
            $display("[%0t] ARBITER tiep tuc xu ly WRITE bi ket!", $time);
            AWVALID_i = 1'b0;
            // Xả Write
            #80 tlast_write_fifo_i = 1'b1; #10 tlast_write_fifo_i = 1'b0;
        end

        #100;
        $display("[%0t] --- KET THUC MO PHONG ---", $time);
        $finish;
    end

    // Monitor: In ra thông tin các gói lệnh được đẩy xuống Hyperbus Master
    always @(posedge clk_i) begin
        if (start_o) begin
            $display("    [HyperBus_CMD] Kich hoat START!");
            $display("    -> R/W: %s | Addr: 24'h%h", 
                cmd_addr_o[47] ? "READ" : "WRITE", 
                {cmd_addr_o[44:16], cmd_addr_o[2:0]});
            $display("    -> Burst Length: %0d words", burst_len_o);
        end
    end

endmodule
