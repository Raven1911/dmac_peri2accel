`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 03:21:30 PM
// Design Name: 
// Module Name: tb_dispatcher
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

module tb_dispatcher;

    // Parameters
    parameter NUM_MASTERS = 2;
    parameter ADDR_WIDTH = 24;
    parameter BURST_WIDTH = 10;

    // Khai báo Inputs (dùng reg)
    // Cập nhật: ID_RW_i giờ là mảng bit [NUM_MASTERS-1:0]
    reg   [NUM_MASTERS-1:0]   ID_RW_i;
    reg   [ADDR_WIDTH-1:0]    AWADDR_i;
    reg   [ADDR_WIDTH-1:0]    ARADDR_i;
    reg   [BURST_WIDTH-1:0]   AWBURST_i;
    reg   [BURST_WIDTH-1:0]   ARBURST_i;
    reg                       READY_i;

    // Khai báo Outputs (dùng wire)
    wire                      AWREADY_o;
    wire                      ARREADY_o;
    wire  [ADDR_WIDTH-1:0]    ADDR_select_o;
    wire  [BURST_WIDTH-1:0]   BURST_select_o;

    // Instantiate module cần test (Device Under Test - DUT)
    dispatcher #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_WIDTH(BURST_WIDTH)
    ) dut (
        .ID_RW_i(ID_RW_i),
        .AWADDR_i(AWADDR_i),
        .ARADDR_i(ARADDR_i),
        .AWBURST_i(AWBURST_i),
        .ARBURST_i(ARBURST_i),
        .AWREADY_o(AWREADY_o),
        .ARREADY_o(ARREADY_o),
        .READY_i(READY_i),
        .ADDR_select_o(ADDR_select_o),
        .BURST_select_o(BURST_select_o)
    );

    // Block khởi tạo và tạo kịch bản test
    initial begin
        // 1. Khởi tạo giá trị ban đầu
        ID_RW_i   = 2'b00; // Trạng thái Idle (Không Read, Không Write)
        READY_i   = 0;
        
        // Gán các giá trị giả lập cho Write Channel
        AWADDR_i  = 24'hAAAAAA; 
        AWBURST_i = 10'h111;
        
        // Gán các giá trị giả lập cho Read Channel
        ARADDR_i  = 24'hBBBBBB;
        ARBURST_i = 10'h222;

        $display("========================================");
        $display("Bắt đầu mô phỏng module Dispatcher");
        $display("========================================");
        #20;

        // --------------------------------------------------
        // TEST CASE 1: Kênh WRITE (One-hot: 2'b01)
        // -> RW_selected[0] = 1, RW_selected[1] = 0
        // --------------------------------------------------
        $display("\n[TEST CASE 1] WRITE Operation (ID_RW_i = 2'b01)");
        ID_RW_i = 2'b01; 
        READY_i = 1'b1;  // Slave đã sẵn sàng
        #10; 
        $display("Input  : READY_i=%b", READY_i);
        $display("Output : ADDR = %h (Kỳ vọng: AAAAAA), BURST = %h (Kỳ vọng: 111)", ADDR_select_o, BURST_select_o);
        $display("Output : AWREADY = %b (Kỳ vọng: 1), ARREADY = %b (Kỳ vọng: 0)", AWREADY_o, ARREADY_o);

        // --------------------------------------------------
        // TEST CASE 2: Kênh READ (One-hot: 2'b10)
        // -> RW_selected[0] = 0, RW_selected[1] = 1
        // --------------------------------------------------
        $display("\n[TEST CASE 2] READ Operation (ID_RW_i = 2'b10)");
        ID_RW_i = 2'b10;
        READY_i = 1'b1;
        #10;
        $display("Input  : READY_i=%b", READY_i);
        $display("Output : ADDR = %h (Kỳ vọng: BBBBBB), BURST = %h (Kỳ vọng: 222)", ADDR_select_o, BURST_select_o);
        $display("Output : AWREADY = %b (Kỳ vọng: 0), ARREADY = %b (Kỳ vọng: 1)", AWREADY_o, ARREADY_o);

        // --------------------------------------------------
        // TEST CASE 3: Slave NOT READY (READY_i = 0)
        // Dù đang Read hay Write thì tín hiệu READY ra cũng phải bằng 0
        // --------------------------------------------------
        $display("\n[TEST CASE 3] Slave NOT READY (READY_i = 0)");
        ID_RW_i = 2'b01; // Thử với Write đang yêu cầu
        READY_i = 1'b0;  // Nhưng Slave bận
        #10;
        $display("Input  : ID_RW_i=%b, READY_i=%b", ID_RW_i, READY_i);
        $display("Output : AWREADY = %b (Kỳ vọng: 0), ARREADY = %b (Kỳ vọng: 0)", AWREADY_o, ARREADY_o);

        // --------------------------------------------------
        // TEST CASE 4: Trạng thái IDLE (ID_RW_i = 2'b00)
        // Không có kênh nào yêu cầu
        // --------------------------------------------------
        $display("\n[TEST CASE 4] IDLE State (ID_RW_i = 2'b00)");
        ID_RW_i = 2'b00; 
        READY_i = 1'b1;  // Slave sẵn sàng nhưng Master không gọi
        #10;
        $display("Input  : ID_RW_i=%b", ID_RW_i);
        $display("Output : AWREADY = %b (Kỳ vọng: 0), ARREADY = %b (Kỳ vọng: 0)", AWREADY_o, ARREADY_o);
        $display("Lưu ý  : ADDR và BURST sẽ nhận giá trị của kênh Read do logic mặc định của toán tử '? :'");

        #20;
        $display("\n========================================");
        $display("Kết thúc mô phỏng.");
        $display("========================================");
        $finish; 
    end

endmodule