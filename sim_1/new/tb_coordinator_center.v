`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 06:01:18 PM
// Design Name: 
// Module Name: tb_coordinator_center
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

module tb_coordinator_center();

    // Parameters
    parameter NUM_MASTERS = 2;
    parameter ADDR_WIDTH = 24;
    parameter BURST_WIDTH = 8;

    // Inputs
    reg clk_i;
    reg resetn_i;
    reg start_ready_i;
    reg wr_read_fifo_i;
    reg tlast_write_fifo_i;
    reg [NUM_MASTERS-1:0] RW_selected_i;
    reg [ADDR_WIDTH-1:0] ADDR_select_i;
    reg [BURST_WIDTH-1:0] BURST_select_i;

    // Outputs
    wire start_o;
    wire [47:0] cmd_addr_o;
    wire [7:0] burst_len_o;
    wire [3:0] latency_o;
    wire [3:0] recovery_o;
    wire [1:0] capture_shmoo_o;
    wire tlast_read_fifo_o;
    wire ready_o;

    // Instantiate UUT
    coordinator_center #(
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
        .RW_selected_i(RW_selected_i), 
        .ADDR_select_i(ADDR_select_i), 
        .BURST_select_i(BURST_select_i), 
        .ready_o(ready_o)
    );

    // Tạo xung Clock 100MHz (Chu kỳ 10ns)
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    integer i;

    // Kịch bản test
    initial begin
        // Khởi tạo
        resetn_i = 0;
        start_ready_i = 0;
        wr_read_fifo_i = 0;
        tlast_write_fifo_i = 0;
        RW_selected_i = 2'b00;
        ADDR_select_i = 24'h0;
        BURST_select_i = 8'h0;

        // Reset system
        #25; 
        resetn_i = 1;
        #10;
        
        // Báo cho FSM biết HyperBus Master đã sẵn sàng
        start_ready_i = 1;

        // ==========================================
        // TEST 1: READ TRANSACTION & TLAST_READ TEST
        // ==========================================
        $display("[%0t] --- START READ TEST ---", $time);
        ADDR_select_i = 24'h000002;
        BURST_select_i = 8'd12; // 12 bytes = burst_len 6
        RW_selected_i = 2'b10;  // Read request
        
        #10 RW_selected_i = 2'b00; // Xóa request sau 1 clock
        
        // Đợi một chút rồi bắt đầu giả lập luồng dữ liệu đẩy vào FIFO
        #30;
        $display("[%0t] FIFO bat dau nhan data...", $time);
        
        // Bơm 12 xung nhịp vào wr_read_fifo_i (Tương ứng 12 byte)
        for (i = 0; i < 12; i = i + 1) begin
            wr_read_fifo_i = 1;
            #10;
            wr_read_fifo_i = 0;
            // Ở byte thứ 10, mạch của bạn (12-2) sẽ bật tlast_read_fifo_o
            if (tlast_read_fifo_o) begin
                $display("[%0t] SUCCESS: tlast_read_fifo_o bat len muc 1 tai byte thu %0d", $time, i+1);
            end
        end
        
        #40;

        // ==========================================
        // TEST 2: WRITE TRANSACTION & TLAST_WRITE TEST
        // ==========================================
        $display("[%0t] --- START WRITE TEST ---", $time);
        ADDR_select_i = 24'h00000A;
        BURST_select_i = 8'd20; // 20 bytes
        RW_selected_i = 2'b01;  // Write request
        
        #10 RW_selected_i = 2'b00;

        // Đợi FSM đi qua WRITE_START -> WRITE_WAIT -> WRITE_END -> WRITE_FINISED
        #60;
        
        $display("[%0t] FSM dang o WRITE_FINISED, cho tlast_write_fifo_i...", $time);
        #20; // Giả lập FSM đang phải chờ FIFO xả xong data

        // Cấp xung tlast_write_fifo_i để giải phóng FSM về IDLE
        tlast_write_fifo_i = 1;
        #10;
        tlast_write_fifo_i = 0;
        $display("[%0t] Da gui tlast_write_fifo_i, FSM quay ve IDLE", $time);

        #50;
        $display("[%0t] --- FINISH SIMULATION ---", $time);
        $finish;
    end

endmodule
