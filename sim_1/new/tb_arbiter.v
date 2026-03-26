`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 12:57:39 PM
// Design Name: 
// Module Name: tb_arbiter
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




module tb_arbiter();
    // Khai báo các tín hiệu kết nối với module (DUT - Design Under Test)
    reg         resetn_i;
    reg         enb_grant_i;
    reg  [1:0]  requite_grant_i;
    wire [1:0]  grant_permission_o;

    // Khởi tạo module arbiter
    arbiter uut (
        .resetn_i(resetn_i),
        .enb_grant_i(enb_grant_i),
        .requite_grant_i(requite_grant_i),
        .grant_permission_o(grant_permission_o)
    );

    // Tạo xung nhịp mô phỏng cho enb_grant_i (Chu kỳ 10ns)
    initial begin
        enb_grant_i = 1'b1;
        forever #5 enb_grant_i = ~enb_grant_i; 
    end

    // Kịch bản tạo tín hiệu kiểm tra (Stimulus)
    initial begin
        // 1. Khởi tạo giá trị ban đầu
        resetn_i = 1'b0;
        requite_grant_i = 2'b00;

        // Giữ reset trong 20ns
        #20;
        resetn_i = 1'b1;
        #10;

        // --------------------------------------------------------
        // KỊCH BẢN 1: Cả hai Master liên tục yêu cầu
        // Mong đợi: Master 0 được cấp 7 lần liên tiếp, sau đó Master 1 được 3 lần.
        // --------------------------------------------------------
        $display("\n--- Kich ban 1: Ca 2 master cung yeu cau lien tuc ---");
        requite_grant_i = 2'b11; 
        #20000; // Chờ đủ lâu để xem hết vòng lặp 7-3

        // --------------------------------------------------------
        // KỊCH BẢN 2: Chỉ Master 1 yêu cầu
        // Mong đợi: Chỉ Master 1 được cấp phép
        // --------------------------------------------------------
        $display("\n--- Kich ban 2: Chi Master 1 yeu cau ---");
        requite_grant_i = 2'b10;
        #100;

        // --------------------------------------------------------
        // KỊCH BẢN 3: Chỉ Master 0 yêu cầu
        // Mong đợi: Chỉ Master 0 được cấp phép
        // --------------------------------------------------------
        $display("\n--- Kich ban 3: Chi Master 0 yeu cau ---");
        requite_grant_i = 2'b01;
        #100;

        // --------------------------------------------------------
        // KỊCH BẢN 4: Ngắt quãng yêu cầu
        // Mong đợi: Bộ đếm trọng số giữ nguyên khi không có yêu cầu, 
        // tiếp tục đếm khi có yêu cầu trở lại.
        // --------------------------------------------------------
        $display("\n--- Kich ban 4: Yeu cau ngat quang ---");
        requite_grant_i = 2'b00; #20;
        requite_grant_i = 2'b11; #50;

        $display("\nHoan thanh mo phong!");
        $finish;
    end

    // Monitor: In kết quả ra console mỗi khi có sườn âm của enb_grant_i
    always @(negedge enb_grant_i) begin
        if (resetn_i) begin
            $display("Time: %4t | Request (M1 M0): %b | Grant (M1 M0): %b | Nhanh uu tien: %d", 
                     $time, requite_grant_i, grant_permission_o, uut.counter_arbiter_unit.count_reg);
        end
    end

endmodule
