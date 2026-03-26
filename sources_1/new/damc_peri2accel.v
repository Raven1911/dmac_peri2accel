`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 11:37:24 AM
// Design Name: 
// Module Name: damc_peri2accel
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
module damc_peri2accel#(
    parameter NUM_MASTERS = 2,
    parameter ADDR_WIDTH = 24,
    parameter BURST_WIDTH = 8
)(
    input                           clk_i,
    input                           resetn_i,
    output                          start_o,
    input                           start_ready_i,
    output      [47:0]              cmd_addr_o,
    output      [7:0]               burst_len_o,
    output      [3:0]               latency_o,
    output      [3:0]               recovery_o,
    output      [1:0]               capture_shmoo_o,

    input                           wr_read_fifo_i,
    output                          tlast_read_fifo_o,

    input                           tlast_write_fifo_i,
    
    input                           AWVALID_i,
    output                          AWREADY_o,
    input       [ADDR_WIDTH-1:0]    AWADDR_i,
    input       [BURST_WIDTH-1:0]   AWBURST_i,

    input                           ARVALID_i,
    output                          ARREADY_o,
    input       [ADDR_WIDTH-1:0]    ARADDR_i,
    input       [BURST_WIDTH-1:0]   ARBURST_i  


    );


    wire  [NUM_MASTERS-1:0]         ID_RW_selected; // one hot
    wire  [ADDR_WIDTH-1:0]          ADDR_select;
    wire  [BURST_WIDTH-1:0]         BURST_select;
    wire                            ready_handshaking;

    arbiter #(
        .NUM_MASTERS(NUM_MASTERS)
    )arbiter_channel_dmac(
        .resetn_i(resetn_i),
        .enb_grant_i(ready_handshaking),
        .requite_grant_i({ARVALID_i, AWVALID_i}),
        .grant_permission_o(ID_RW_selected)
    );


    coordinator_center #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_WIDTH(BURST_WIDTH)
    ) coordinator_center_dmac (
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
        .RW_selected_i(ID_RW_selected), 
        .ADDR_select_i(ADDR_select), 
        .BURST_select_i(BURST_select), 
        .ready_o(ready_handshaking)
    );


    dispatcher #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BURST_WIDTH(BURST_WIDTH)
    ) dispatcher_dmac (
        .ID_RW_i(ID_RW_selected),
        .AWADDR_i(AWADDR_i),
        .ARADDR_i(ARADDR_i),
        .AWBURST_i(AWBURST_i),
        .ARBURST_i(ARBURST_i),
        .AWREADY_o(AWREADY_o),
        .ARREADY_o(ARREADY_o),
        .READY_i(ready_handshaking),
        .ADDR_select_o(ADDR_select),
        .BURST_select_o(BURST_select)
    );



endmodule




module coordinator_center#(
    parameter NUM_MASTERS = 2,
    parameter ADDR_WIDTH = 24,
    parameter BURST_WIDTH = 8

)(
    input               clk_i,
    input               resetn_i,

    output              start_o,
    input               start_ready_i,
    
    output  [47:0]      cmd_addr_o,
    output  [7:0]       burst_len_o,
    output  [3:0]       latency_o,
    output  [3:0]       recovery_o,
    output  [1:0]       capture_shmoo_o,

    input               wr_read_fifo_i,
    output              tlast_read_fifo_o,

    input               tlast_write_fifo_i,


    input   [NUM_MASTERS-1:0]   RW_selected_i,
    input   [ADDR_WIDTH-1:0]    ADDR_select_i,
    input   [BURST_WIDTH-1:0]   BURST_select_i,

    output                      ready_o
    
);


    localparam  [3:0]   IDLE = 0,
                        WRITE_START = 1,
                        WRITE_WAIT = 2,
                        WRITE_END = 3,
                        WRITE_FINISED = 4,
                        READ_START = 5;
                        




    reg [3:0]       state_reg, state_next;
    reg [47:0]      cmd_addr_reg, cmd_addr_next;
    reg [7:0]       burst_len_reg, burst_len_next;
    reg [3:0]       latency_reg, latency_next;
    reg [3:0]       recovery_reg, recovery_next;
    reg [1:0]       capture_shmoo_reg, capture_shmoo_next;
    reg             start_transaction_reg, start_transaction_next;
    reg             ready_reg, ready_next;


    reg [9:0]       tlast_counter_reg, tlast_counter_next;
    reg             tlast_read_fifo_reg, tlast_read_fifo_next;
    


    // Seq circuit 
    always @(posedge clk_i or negedge resetn_i) begin
        if (~resetn_i) begin
            state_reg <= IDLE;
        end

        else begin
            state_reg <= state_next;
        end

    end

    always @(posedge clk_i or negedge resetn_i) begin
        if (~resetn_i) begin
            cmd_addr_reg <= 0;
            burst_len_reg <= 0;
            latency_reg <= 0;
            recovery_reg <= 0;
            capture_shmoo_reg <= 0;
            start_transaction_reg <= 0;
            ready_reg <= 0;
        end
        else begin
            cmd_addr_reg <= cmd_addr_next;
            burst_len_reg <= burst_len_next;
            latency_reg <= latency_next;
            recovery_reg <= recovery_next;
            capture_shmoo_reg <= capture_shmoo_next;
            start_transaction_reg <= start_transaction_next;
            ready_reg <= ready_next;
        end

    end


    always @(*) begin
        state_next = state_reg;
        cmd_addr_next = cmd_addr_reg;
        burst_len_next = burst_len_reg; 
        latency_next = latency_reg;
        recovery_next = recovery_reg;
        capture_shmoo_next = capture_shmoo_reg;
        start_transaction_next = start_transaction_reg;
        ready_next = ready_reg;
    
        case (state_reg) 
            IDLE: begin
                start_transaction_next = 1'b0;
                ready_next = 1'b0;
                if (start_ready_i) begin
                    if (RW_selected_i[0]) begin
                        state_next = WRITE_START;
                        cmd_addr_next = {
                                            1'b0,                         // CA[47]    : R/W#
                                            1'b0,                         // CA[46]    : Address Space (Memory)
                                            1'b1,                         // CA[45]    : Burst Type (Linear)
                                            8'b0, ADDR_select_i[23:3],    // CA[44:16] : Row & Upper Column Address
                                            13'b0,                        // CA[15:3]  : Reserved
                                            ADDR_select_i[2:0]            // CA[2:0]   : Lower Column Address
                                        };
                        burst_len_next = BURST_select_i[BURST_WIDTH-1 : 1];
                        latency_next = 4'd7;
                        recovery_next = 4'd8;
                        capture_shmoo_next = 2'd2;
                        ready_next = 1'b1;

        
                        
                    end
                    else if (RW_selected_i[1]) begin
                        state_next = READ_START;
                        cmd_addr_next = {
                                            1'b1,                         // CA[47]    : R/W# (1 = Read)
                                            1'b0,                         // CA[46]    : Address Space (Memory)
                                            1'b1,                         // CA[45]    : Burst Type (Linear)
                                            8'b0, ADDR_select_i[23:3],    // CA[44:16] : Row & Upper Column Address
                                            13'b0,                        // CA[15:3]  : Reserved
                                            ADDR_select_i[2:0]            // CA[2:0]   : Lower Column Address
                                        };
                        burst_len_next = BURST_select_i[BURST_WIDTH-1 : 1];
                        latency_next = 4'd7;
                        recovery_next = 4'd8;
                        capture_shmoo_next = 2'd2;
                        start_transaction_next = 1'b1;
                        ready_next = 1'b1;
                    end
                    
                    else begin
                        state_next = IDLE;
                    end
                end
            end
            WRITE_START: begin
                ready_next = 1'b0;
                state_next = WRITE_WAIT;

            end
            WRITE_WAIT: begin
                state_next = WRITE_END;
            end
            WRITE_END: begin
                start_transaction_next = 1'b1;
                state_next = WRITE_FINISED;
            end
            WRITE_FINISED: begin
                start_transaction_next = 1'b0;
                if (tlast_write_fifo_i) begin
                    state_next = IDLE;
                end
            end

            READ_START: begin
                start_transaction_next = 1'b0;
                ready_next = 1'b0;
                state_next = IDLE;
            end
        endcase
    end



    always @(posedge clk_i or negedge resetn_i) begin
        if (~resetn_i) begin
            tlast_counter_reg <= 0;
            tlast_read_fifo_reg <= 0;
        end
        else begin
            tlast_counter_reg <= tlast_counter_next;
            tlast_read_fifo_reg <= tlast_read_fifo_next;
        end

        
    end

    always @(*) begin
        tlast_counter_next = tlast_counter_reg;
        tlast_read_fifo_next = 0;
        if (wr_read_fifo_i) begin
            tlast_counter_next = tlast_counter_reg + 1;
        end
        if (tlast_counter_reg >= (burst_len_reg << 1)) begin
            tlast_counter_next = 0;
            
        end

        if (tlast_counter_reg == ((burst_len_reg << 1) - 1)) begin
            tlast_read_fifo_next = 1'b1;
        end    
    end


    assign cmd_addr_o       = cmd_addr_reg;
    assign burst_len_o      = burst_len_reg;
    assign latency_o        = latency_reg;
    assign recovery_o       = recovery_reg;
    assign capture_shmoo_o  = capture_shmoo_reg;
    assign start_o          = start_transaction_reg;
    assign ready_o          = ready_reg;

    assign tlast_read_fifo_o = tlast_read_fifo_reg;
    

endmodule





module dispatcher#(
    parameter NUM_MASTERS = 2,
    parameter ADDR_WIDTH = 24,
    parameter BURST_WIDTH = 10
)(
    input   [NUM_MASTERS-1:0]   ID_RW_i,
    input   [ADDR_WIDTH-1:0]    AWADDR_i,
    input   [ADDR_WIDTH-1:0]    ARADDR_i,

    input   [BURST_WIDTH-1:0]   AWBURST_i,
    input   [BURST_WIDTH-1:0]   ARBURST_i,

    output                      AWREADY_o,
    output                      ARREADY_o,


    input                       READY_i,
    output  [ADDR_WIDTH-1:0]    ADDR_select_o,
    output  [BURST_WIDTH-1:0]   BURST_select_o

);

    wire [NUM_MASTERS-1:0] RW_selected;


    assign ADDR_select_o =  RW_selected[0] ? AWADDR_i : ARADDR_i;
    assign BURST_select_o = RW_selected[0] ? AWBURST_i : ARBURST_i;
    
    assign AWREADY_o =  RW_selected[0] ? READY_i : 1'b0;
    assign ARREADY_o =  RW_selected[1] ? READY_i : 1'b0;

    assign RW_selected = ID_RW_i;
    




endmodule



module arbiter#(
    parameter NUM_MASTERS = 2,
    parameter [NUM_MASTERS*NUM_MASTERS-1:0] ID_MASTERS_MAPS = {
        { 1'b1, {(NUM_MASTERS-1){1'b0}} },
        // Master 0: bit 0 = 1, others = 0
        { {(NUM_MASTERS-1){1'b0}}, 1'b1 }
    }
)(  
    input                                               resetn_i,
    input                                               enb_grant_i,
    input   [NUM_MASTERS-1:0]                           requite_grant_i,

    output  [NUM_MASTERS-1:0]                           grant_permission_o // id one hot

);  
    


    wire    [$clog2(NUM_MASTERS)-1:0]                   number_signal;
    reg     [NUM_MASTERS*NUM_MASTERS-1:0]               Master_ID_Map;

    // combi circuit for round robin
    integer ni_mters_comb;
    integer nj_mters_comb;
    always @(*) begin
        Master_ID_Map = 'd0;
        for (nj_mters_comb = 0; nj_mters_comb < NUM_MASTERS; nj_mters_comb = nj_mters_comb + 1) begin
            if (nj_mters_comb == 0) begin
                for (ni_mters_comb = NUM_MASTERS - 1 - nj_mters_comb; ni_mters_comb >= 0; ni_mters_comb = ni_mters_comb - 1) begin
                    if (requite_grant_i[ni_mters_comb]) begin
                        Master_ID_Map[((NUM_MASTERS*nj_mters_comb) + NUM_MASTERS - 1) -: NUM_MASTERS] = ID_MASTERS_MAPS[((NUM_MASTERS*ni_mters_comb) + NUM_MASTERS - 1) -: NUM_MASTERS];  
                    end
                end
            end
            else begin
                for (ni_mters_comb = nj_mters_comb - 1; ni_mters_comb >= 0; ni_mters_comb = ni_mters_comb - 1) begin
                    if (requite_grant_i[ni_mters_comb]) begin
                        Master_ID_Map[((NUM_MASTERS*nj_mters_comb) + NUM_MASTERS - 1) -: NUM_MASTERS] = ID_MASTERS_MAPS[((NUM_MASTERS*ni_mters_comb) + NUM_MASTERS - 1) -: NUM_MASTERS];  
                    end 
                end
                for (ni_mters_comb = NUM_MASTERS - 1; ni_mters_comb >= nj_mters_comb; ni_mters_comb = ni_mters_comb - 1) begin
                    if (requite_grant_i[ni_mters_comb]) begin
                        Master_ID_Map[((NUM_MASTERS*nj_mters_comb) + NUM_MASTERS - 1) -: NUM_MASTERS] = ID_MASTERS_MAPS[((NUM_MASTERS*ni_mters_comb) + NUM_MASTERS - 1) -: NUM_MASTERS];  
                    end 
                end
              
            end
        end

    end


    counter_arbiter #(
        // .NUM_MASTERS(NUM_MASTERS)
    ) counter_arbiter_unit (
        .tick_count_i(enb_grant_i),
        .resetn_i(resetn_i),
        .grant_permission_i(grant_permission_o),
        .number_o(number_signal)
    );

    mux_ID_arbiter #(
        .NUM_MASTERS(NUM_MASTERS)
    ) mux_ID_arbiter_unit (

        .Master_ID_Selected_i(Master_ID_Map),
        .number_select_i(number_signal),
        .Master_ID_Selected_o(grant_permission_o)
    );
endmodule


module counter_arbiter#(
    parameter NUM_MASTERS = 2,
    parameter WEIGHT_M0   = 100,              //M0 write
    parameter WEIGHT_M1   = 3                 //M1 read
       
)(  
    input                                   tick_count_i,
    input                                   resetn_i,  
    input   [1:0]                           grant_permission_i, // id one hot

    output  [$clog2(NUM_MASTERS)-1:0]       number_o

);  

    

    reg [$clog2(NUM_MASTERS)-1:0] count_reg, count_next;

    reg [9:0] weight_counter_m0_reg, weight_counter_m0_next;
    reg [9:0] weight_counter_m1_reg, weight_counter_m1_next;

    always @(negedge tick_count_i or negedge resetn_i) begin
        if (~resetn_i) begin
            count_reg <= 0;
            weight_counter_m0_reg <= 0;
            weight_counter_m1_reg <= 0;
        end
        else begin
            count_reg <= count_next;
            weight_counter_m0_reg <= weight_counter_m0_next;
            weight_counter_m1_reg <= weight_counter_m1_next;
        end
    end

    always @(*) begin
        count_next = count_reg;
        weight_counter_m0_next = weight_counter_m0_reg;
        weight_counter_m1_next = weight_counter_m1_reg;
        if (count_reg >= NUM_MASTERS) begin
            count_next = 0;
        end
        if (grant_permission_i[0]) begin
            weight_counter_m0_next = weight_counter_m0_reg + 1;
            if (weight_counter_m0_next >= WEIGHT_M0) begin
                weight_counter_m0_next = 0;
                count_next = count_reg + 1;
            end
        end
        else if (grant_permission_i[1]) begin
            weight_counter_m1_next = weight_counter_m1_reg + 1;
            if (weight_counter_m1_next >= WEIGHT_M1) begin
                weight_counter_m1_next = 0;
                count_next = count_reg + 1;
            end
        end 

    end

    assign  number_o = count_reg;

endmodule

module mux_ID_arbiter#(
    parameter NUM_MASTERS = 16
)(
    input   [NUM_MASTERS*NUM_MASTERS-1:0]   Master_ID_Selected_i,
    input   [$clog2(NUM_MASTERS)-1:0]       number_select_i,
    output  [NUM_MASTERS-1:0]               Master_ID_Selected_o
);

    assign Master_ID_Selected_o = Master_ID_Selected_i[((number_select_i * NUM_MASTERS) + NUM_MASTERS -1)  -: NUM_MASTERS];

endmodule



