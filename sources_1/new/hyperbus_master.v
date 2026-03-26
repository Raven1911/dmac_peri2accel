`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/25/2026 09:09:47 PM
// Design Name: 
// Module Name: hyperbus_master
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

module hyperbus_master#(
    parameter W_BURSTLEN = 8,
    parameter ADDR_WIDTH_FIFO = 8,
    parameter DATA_WIDTH_FIFO = 8,
    parameter DATA_WIDTH_BYTE = 1,
    parameter INTERFACE_MOD = 1 // 0: FIFO interface, 1: AXIS interface  
)(
	input wire                   clk,
	input wire                   rst_n,

	// Control

	input  wire [47:0]           cmd_addr,      // Full contents of the hyperbus CA packet
	input  wire                  start,         // Start a new DRAM/register access sequence
	output wire                  start_rdy,     // Interface is ready to start a sequence
	input  wire [W_BURSTLEN-1:0] burst_len,     // Number of halfwords to transfer (double number of bytes)
	input  wire [3:0]            latency,       // Number of clocks between CA[23:16] being transferred, and first read/write data. Doubled if RWDS high during CA. >= 2
	input  wire [3:0]            recovery,      // Number of clocks to wait 
	input  wire [1:0]            capture_shmoo, // Capture DQi at 0, 180 or 360 clk degrees (0 90 180 HCLK degrees) after the DDR HCLK
	                                            // edge which causes it to transition to *next* data. 0 degrees probably correct for almost all speeds.
	                                            // 2 -> 0 degrees
	                                            // 1 -> 180 degrees
	                                            // 0 -> 360 degrees

	// Data
	input  wire [7:0]            wdata_i,
	input  wire                  wr_i, // Backpressure only. Host must always provide valid data during a write transaction
	output wire [7:0]            rdata_o,
	input  wire                  rd_i, // Forward pressure only. Host must always accept data it has previously requested
    output wire                  full_o,
    output wire                  empty_o,

	// HyperBus
    inout   [7:0]                dq_io,
    inout                        rwds_io,

	output                       hclk_p,  // For 3V RAMs, just use the single-ended (positive) clock
	output                       hclk_n,

	output                       cs_n,

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

    output                          wr_read_fifo_o,
    input                           tlast_read_fifo_i,
    output                          tlast_write_fifo_o
);

    wire [7:0]            dq_i;
	wire [7:0]            dq_o;
	wire [7:0]            dq_oe;

    wire                  rwds_i;
	wire                  rwds_o;
	wire                  rwds_oe;

    // Data ip to fifo
	wire [7:0]            wdata;
	wire                  wdata_rdy; // Backpressure only. Host must always provide valid data during a write transaction
	wire [7:0]            rdata;
	wire                  rdata_vld; // Forward pressure only. Host must always accept data it has previously requested

	//wire edge
	wire 				  edge_wr;
	wire 				  edge_rd;
    wire                  edge_start;



     // ------------------------------------------------------------
    // Tri-state buffer mapping
    // ------------------------------------------------------------
    // DQ bus (8-bit bidirectional)
    assign dq_io = dq_oe ? dq_o : 8'bz;  // dq_oe = 1(FF)  dq_io = dq_o, else dq_io = high-Z
    assign dq_i  = dq_io;                // for read

    // RWDS (1-bit bidirectional)
    assign rwds_io = rwds_oe ? rwds_o : 1'bz; 
    assign rwds_i  = rwds_io;

    generate
        if (INTERFACE_MOD == 0) begin
            // ------------------------------------------------------------
            // Instance of hyperbus_interface
            // ------------------------------------------------------------
            hyperbus_interface #(
                .W_BURSTLEN(W_BURSTLEN)
            ) dut (
                .clk           (clk),
                .rst_n         (rst_n),
                .cmd_addr      (cmd_addr),
                .start         (edge_start),
                .start_rdy     (start_rdy),
                .burst_len     (burst_len),
                .latency       (latency),
                .recovery      (recovery),
                .capture_shmoo (capture_shmoo),
                .wdata         (wdata),
                .wdata_rdy     (wdata_rdy),
                .rdata         (rdata),
                .rdata_vld     (rdata_vld),
                .dq_i          (dq_i),
                .dq_o          (dq_o),
                .dq_oe         (dq_oe),
                .rwds_i        (rwds_i),
                .rwds_o        (rwds_o),
                .rwds_oe       (rwds_oe),
                .hclk_p        (hclk_p),
                .hclk_n        (hclk_n),
                .cs_n          (cs_n)
            );

            edge_detector_hyperbus edge_start_unit (
                .clk(clk),
                .reset_n(rst_n),
                .level_edge(start),
                .p_edge(edge_start),
                .n_edge(),
                .any_edge()
            );


            fifo_hyperbus_unit#(
                .ADDR_WIDTH(ADDR_WIDTH_FIFO),
                .DATA_WIDTH(DATA_WIDTH_FIFO)
            ) buffer_wdata (
                .clk(clk), 
                .reset_n(rst_n),
                .wr(edge_wr), 
                .rd(wdata_rdy),

                .w_data(wdata_i), //writing data
                .r_data(wdata), //reading data

                .full(full_o), 
                .empty()
            );

            edge_detector_hyperbus edge_wdata (
                .clk(clk),
                .reset_n(rst_n),
                .level_edge(wr_i),
                .p_edge(edge_wr),
                .n_edge(),
                .any_edge()
            );

            fifo_hyperbus_unit#(
                .ADDR_WIDTH(ADDR_WIDTH_FIFO),
                .DATA_WIDTH(DATA_WIDTH_FIFO)
            ) buffer_rdata (
                .clk(clk), 
                .reset_n(rst_n),
                .wr(rdata_vld), 
                .rd(edge_rd),

                .w_data(rdata), //writing data
                .r_data(rdata_o), //reading data

                .full(), 
                .empty(empty_o)
            );

            edge_detector_hyperbus edge_rdata (
                .clk(clk),
                .reset_n(rst_n),
                .level_edge(rd_i),
                .p_edge(edge_rd),
                .n_edge(),
                .any_edge()
            );

        end

        else if (INTERFACE_MOD == 1) begin
            hyperbus_interface #(
                .W_BURSTLEN(W_BURSTLEN)
            ) dut (
                .clk           (clk),
                .rst_n         (rst_n),
                .cmd_addr      (cmd_addr),
                .start         (start),
                .start_rdy     (start_rdy),
                .burst_len     (burst_len),
                .latency       (latency),
                .recovery      (recovery),
                .capture_shmoo (capture_shmoo),

                .wdata         (wdata),
                .wdata_rdy     (wdata_rdy),
                .rdata         (rdata),
                .rdata_vld     (rdata_vld),

                .dq_i          (dq_i),
                .dq_o          (dq_o),
                .dq_oe         (dq_oe),
                .rwds_i        (rwds_i),
                .rwds_o        (rwds_o),
                .rwds_oe       (rwds_oe),
                .hclk_p        (hclk_p),
                .hclk_n        (hclk_n),
                .cs_n          (cs_n)
            );
            // DUT Master
            axi4_stream #(
                .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE), 
                .SELECT_INTERFACE(0), 
                .SIZE_FIFO(8)
            ) fifo_m (
                .aclk_i(clk), 
                .aresetn_i(rst_n), 
                .m_tvalid_o(m_tvalid_o), 
                .m_tready_i(m_tready_i), 
                .m_tdata_o(m_tdata_o), 
                .m_tstrb_o(m_tstrb_o), 
                .m_tkeep_o(m_tkeep_o), 
                .m_tlast_o(m_tlast_o), 
                .user_m_busy_o(), 
                .user_m_wr_data_i(rdata_vld), 
                .user_m_data_i(rdata), 
                .user_m_tstrb_i(1), 
                .user_m_tkeep_i(1), 
                .user_m_tlast_i(tlast_read_fifo_i),

                .s_tready_o(), 
                .user_s_ready_o(), 
                .user_s_data_o());     
            end
            assign wr_read_fifo_o = rdata_vld;


            axi4_stream #(
                .DATA_WIDTH_BYTE(DATA_WIDTH_BYTE), 
                .SELECT_INTERFACE(1), 
                .SIZE_FIFO(8)
            ) fifo_s (
                .aclk_i(clk), 
                .aresetn_i(rst_n), 
                .s_tvalid_i(s_tvalid_i), 
                .s_tready_o(s_tready_o), 
                .s_tdata_i(s_tdata_i), 
                .s_tstrb_i(s_tstrb_i), 
                .s_tkeep_i(s_tkeep_i), 
                .s_tlast_i(s_tlast_i), 
                .user_s_ready_o(), 
                .user_s_rd_data_i(wdata_rdy), 
                .user_s_data_o(wdata), 
                .user_s_tstrb_o(), 
                .user_s_tkeep_o(), 
                .user_s_tlast_o(tlast_write_fifo_o), 
                .m_tvalid_o(), 
                .user_m_busy_o());
                    
                
    endgenerate





endmodule







// Encapsulates all the timing details of the HyperBus interface
// Contains some half-cycle paths, but these should all be register-register
// (or at most a couple of muxes)

// HyperBus is a DDR interface. Each transaction consists of:
// - CSn assertion while clock is idle (low)
// - A 48 bit command and address (CA) sequence, clocked out on 6 edges
// - An access latency period. Latency clock count is configured via config register in the HRAM,
//   and latency is doubled if a RAM refresh operation is in progress, which is signalled by RWDS
//   high during CA phase.
// - A read/write data burst transferring one byte per clock edge, even number of bytes total.
// - CSn deassertion while clock idle, to terminate the burst
// - A short recovery period before reasserting CSn
//
// HCLK need not be free-running.
// 
// During write data bursts, RWDS functions as a byte masking signal, allowing
// individual bytes on a DRAM row to be updated without R-M-W sequence. We don't use this.
// 
// CA, write data, and RWDS (during write bursts) should be centre-clocked by the HCLK signal,
// so that the slave capture is aligned with the signal eye.
// 
// CSn ¬¬¬____________________________________¬¬¬¬
// CLK __________¬¬¬¬¬¬¬¬________¬¬¬¬¬¬¬¬_________
// DQ  ------<  A   ><  B   ><  C   ><  D   >
//
//
// During read data bursts, RWDS is used as a source-synchronous DDR strobe, aligned
// with DQ transitions. Some RAMs also have a secondary clock input which allows
// RWDS to be skewed to align it with the DQ eye. As we are only aiming for low speed operation,
// we will simply capture DQ on our transmitted clock. TODO: some shmooing on the capture?
//
// For register accesses, there is no latency period: CA is followed immediately by a 16-bit register value.
// The entire access occurs on 8 consecutive clock edges.


module hyperbus_interface #(
	parameter W_BURSTLEN = 5
) (
	input wire                   clk,
	input wire                   rst_n,

	// Control

	input  wire [47:0]           cmd_addr,      // Full contents of the hyperbus CA packet
	input  wire                  start,         // Start a new DRAM/register access sequence
	output wire                  start_rdy,     // Interface is ready to start a sequence
	input  wire [W_BURSTLEN-1:0] burst_len,     // Number of halfwords to transfer (double number of bytes)
	input  wire [3:0]            latency,       // Number of clocks between CA[23:16] being transferred, and first read/write data. Doubled if RWDS high during CA. >= 2
	input  wire [3:0]            recovery,      // Number of clocks to wait 
	input  wire [1:0]            capture_shmoo, // Capture DQi at 0, 180 or 360 clk degrees (0 90 180 HCLK degrees) after the DDR HCLK
	                                            // edge which causes it to transition to *next* data. 0 degrees probably correct for almost all speeds.
	                                            // 2 -> 0 degrees
	                                            // 1 -> 180 degrees
	                                            // 0 -> 360 degrees

	// Data

	input  wire [7:0]            wdata,
	output wire                  wdata_rdy, // Backpressure only. Host must always provide valid data during a write transaction
	output wire [7:0]            rdata,
	output wire                  rdata_vld, // Forward pressure only. Host must always accept data it has previously requested

	// HyperBus

	input  wire [7:0]            dq_i,
	output wire [7:0]            dq_o,
	output wire [7:0]            dq_oe,

	input  wire                  rwds_i,
	output wire                  rwds_o,
	output wire                  rwds_oe,

	output  reg                  hclk_p,  // For 3V RAMs, just use the single-ended (positive) clock
	output  reg                  hclk_n,

	output  reg                  cs_n
);

// ----------------------------------------------------------------------------
// Hyperbus state machine

localparam W_STATE = 3;

localparam S_IDLE     = 3'd0; // Ready to start a new sequence
localparam S_SETUP    = 3'd1; // Asserting CS and first CA byte
localparam S_CA       = 3'd2; // Driving clock and shifting CA packet
localparam S_LATENCY  = 3'd3; // Driving clock until access latency elapses
localparam S_RBURST   = 3'd4; // Driving clock and capturing read data
localparam S_WBURST   = 3'd5; // Driving clock and write data
localparam S_RECOVERY = 3'd6; // Hold CS high a while before accepting new command

reg [W_STATE-1:0] bus_state_next; // combinatorial
reg [W_STATE-1:0] bus_state;
reg [W_STATE-1:0] bus_state_prev;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		bus_state <= S_IDLE;
		bus_state_prev <= S_IDLE;
	end else begin
		bus_state <= bus_state_next;
		bus_state_prev <= bus_state;
	end
end

// Some useful housekeeping values

reg [W_BURSTLEN-1:0] cycle_ctr;

reg latency_2x; // RWDS sample taken during CA phase (2 clocks in seems ok)
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		latency_2x <= 1'b0;
	else if (bus_state == S_CA && cycle_ctr == 5'h3 && hclk_p)
		latency_2x <= rwds_i;

reg is_reg_write;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		is_reg_write <= 1'b0;
	else if (start_rdy)
		is_reg_write <= start && cmd_addr[47:46] == 2'b01;

reg is_write;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		is_write <= 1'b0;
	else if (start && start_rdy)
		is_write <= !cmd_addr[47];

// Counter logic

// - 1 because the count starts after row address (1 hclk before end of CA)
wire [W_BURSTLEN-1:0] latency_after_ca = (latency << latency_2x) - 5'h1;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		cycle_ctr <= {W_BURSTLEN{1'b0}};
	end else begin
		if (bus_state == S_IDLE && bus_state_next == S_CA) begin
			cycle_ctr <= 5'h3;
		end else if (bus_state == S_CA && bus_state_next == S_LATENCY) begin
			cycle_ctr <= latency_after_ca;
			// Note that for low latency settings (2 cycles) we go straight from CA to burst if RWDS was low:
		end else if ((bus_state == S_CA || bus_state == S_LATENCY) && (bus_state_next == S_RBURST || bus_state_next == S_WBURST)) begin
			cycle_ctr <= is_reg_write ? 1 : burst_len;
		end else if (hclk_p) begin
			// Counter transitions each time hclk returns to idle state (count full pulses, not DDR edges)
			cycle_ctr <= cycle_ctr - 1'b1;
		end
	end
end

// Main state transitions

wire final_edge = cycle_ctr == 5'h1 && hclk_p;

always @ (*) begin
	bus_state_next = bus_state;
	case (bus_state)
	S_IDLE: begin
		if (start)
			bus_state_next = S_CA;
	end
	S_CA: begin
		if (final_edge) begin
			if (|latency_after_ca && !is_reg_write)
				bus_state_next = S_LATENCY;
			else
				bus_state_next = is_write ? S_WBURST : S_RBURST;
		end
	end
	S_LATENCY: begin
		if (final_edge)
			bus_state_next = is_write ? S_WBURST : S_RBURST;
	end
	S_RBURST: begin
		if (final_edge)
			bus_state_next = S_RECOVERY;
	end
	S_WBURST: begin
		if (final_edge)
			bus_state_next = S_RECOVERY;
	end
	S_RECOVERY: begin
		bus_state_next = S_IDLE; //TODO add some way of controlling this length
	end

	endcase
end

// ----------------------------------------------------------------------------
// Handle non-DQ bus signals

wire drive_clk =
	bus_state == S_CA      ||
	bus_state == S_LATENCY ||
	bus_state == S_WBURST  ||
	bus_state == S_RBURST  ;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		hclk_p <= 1'b0;
		hclk_n <= 1'b1;
	end else if (drive_clk) begin
		hclk_p <= hclk_n;
		hclk_n <= hclk_p;
	end
end

// Used as a byte strobe during writes. Except when:
//   36. The host must not drive RWDS during a write to register space.

reg rwds_assert;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		rwds_assert <= 1'b0;
	else
		rwds_assert <= bus_state_next == S_WBURST && !is_reg_write;

reg rwds_assert_falling;
always @ (negedge clk or negedge rst_n)
	if (!rst_n)
		rwds_assert_falling <= 1'b0;
	else
		rwds_assert_falling <= rwds_assert;

// Active-LOW byte strobe
assign rwds_o = 1'b0;
assign rwds_oe = rwds_assert_falling;

always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		cs_n <= 1'b1; // active high, deassert at reset
	else
		cs_n <= bus_state_next == S_IDLE || bus_state == S_RECOVERY;

// ----------------------------------------------------------------------------
// Launch/capture flops for DQ (half-clock retiming)

reg [7:0] dq_o_reg;
reg [7:0] dq_o_reg_falling;

// HCLK transitions align with posedge of clk.
// DQ outputs are eye-aligned, so we write bus data to dq_o_reg on the posedge 
// *before* the HCLK transition, and then register again via dq_o_reg_falling 
// to align transitions with clk negedge.

always @ (negedge clk or negedge rst_n)
	if (!rst_n)
		dq_o_reg_falling <= 8'h0;
	else
		dq_o_reg_falling <= dq_o_reg;


assign dq_o = dq_o_reg_falling;

// Drive period is aligned with assertion of write data
// i.e. we generate it one clk before the HCLK edge
// and then delay by half a clock

reg dq_oe_reg;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		dq_oe_reg <= 1'b0;
	else
		dq_oe_reg <= bus_state_next == S_WBURST || bus_state_next == S_CA;

reg dq_oe_reg_falling;
always @ (negedge clk or negedge rst_n)
	if (!rst_n)
		dq_oe_reg_falling <= 1'b0;
	else
		dq_oe_reg_falling <= dq_oe_reg;

assign dq_oe = {8{dq_oe_reg_falling}};

// Read is going to need some diagrams :)

wire [7:0] dq_i_delay;

prog_halfclock_delay #(
	.MAX_DELAY(2),
	.FINAL_FALLING(1)
) dq_i_delay_line [7:0] (
	.clk (clk),
	.in  (dq_i),
	.sel (capture_shmoo),
	.out (dq_i_delay)
);

reg [7:0] dq_i_reg;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		dq_i_reg <= 8'h0;
	else
		dq_i_reg <= dq_i_delay;

// ----------------------------------------------------------------------------
// Host interfaces


// The first byte of CA packet goes straight to bus. Rest is captured and shifted:
reg [39:0] ca_shift;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		ca_shift <= 40'h0;
	else if (bus_state_next == S_CA && bus_state != S_CA)
		ca_shift <= cmd_addr[39:0];
	else
		ca_shift <= ca_shift << 8;

// Recall that dq_o_reg is delayed by half a clk before appearing on bus,
// and is captured on the *following* HCLK transition.
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		dq_o_reg <= 8'h0;
	else if (bus_state_next == S_CA)
		dq_o_reg <= bus_state == S_CA ? ca_shift[39:32] : cmd_addr[47:40];
	else
		dq_o_reg <= wdata;

assign wdata_rdy = bus_state_next == S_WBURST;

reg [1:0] rdata_vld_reg;
always @ (posedge clk or negedge rst_n)
	if (!rst_n)
		rdata_vld_reg <= 2'b00;
	else
		rdata_vld_reg <= {rdata_vld_reg[0], bus_state_prev == S_RBURST};

assign rdata_vld = rdata_vld_reg[1];
assign rdata = dq_i_reg;

assign start_rdy = bus_state == S_IDLE;


endmodule




// Alternating posedge/negedge register stages for *input* timing adjustment
//
// Mux sels are decoded from input select. At most one will be selecting the "in" net
// 
// in -+------+-------------+-------------+
//     |      |             |             |
//     |      +--|\         +--|\         +--|\     
//     |         | |           | |           | |    
//     |  +---+  | |-+  +---+  | |-+  +---+  | |---- out 
//     +--|D Q|--|/  +--|D Q|--|/  +--|D Q|--|/
//        |   |         |   |         |   |         
//        +-^-+         +-^-+         +-^-+         
//          o             |             o
//          |             |             |
// clk -----+-------------+-------------+
//
// Above is for a MAX_DELAY of 3

module prog_halfclock_delay #(
	parameter MAX_DELAY = 2,                // Number of register stages to insert
	parameter FINAL_FALLING = 1,          // If 1, final stage is falling edge
	parameter W_SEL = $clog2(MAX_DELAY + 1) // let this default
) (
	input wire clk,
	input wire in,
	input wire [W_SEL-1:0] sel,
	output wire out
);

(* keep = 1'b1 *) reg [MAX_DELAY-1:0] q;
                  reg [MAX_DELAY  :0] d;

// Insert bypass muxes
// Numbering is a bit odd: d[i] is the D *generated from* q[i]
// i.e. the input to the following flop

always @ (*) begin: bypass
	integer i;
	for (i = 0; i <= MAX_DELAY; i = i + 1) begin
		if (i == MAX_DELAY || sel == i)
			d[i] = in;
		else
			d[i] = q[i];
	end
end

genvar i;
generate
for (i = 0; i < MAX_DELAY; i = i + 1) begin: flops
	if (i[0] ^ |FINAL_FALLING) begin
		always @ (negedge clk)
			q[i] <= d[i + 1];
	end else begin
		always @ (posedge clk)
			q[i] <= d[i + 1];
	end
end
endgenerate

assign out = d[0];

endmodule



//module fifo
module fifo_hyperbus_unit #(parameter ADDR_WIDTH = 3, DATA_WIDTH = 8)(
    input clk, reset_n,
    input wr, rd,

    input [DATA_WIDTH - 1 : 0] w_data, //writing data
    output [DATA_WIDTH - 1 : 0] r_data, //reading data

    output full, empty

    );

    //signal
    wire [ADDR_WIDTH - 1 : 0] w_addr, r_addr;

    //instantiate registers file
    register_file_hyperbus #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
        register_file_hyperbus_unit(
            .clk(clk),
            .w_en(~full & wr),

            .r_addr(r_addr), //reading address
            .w_addr(w_addr), //writing address

            .w_data(w_data), //writing data
            .r_data(r_data) //reading data
        
        );

    //instantiate fifo ctrl
    fifo_ctrl_hyperbus #(.ADDR_WIDTH(ADDR_WIDTH))
        fifo_ctrl_hyperbus_unit(
            .clk(clk), 
            .reset_n(reset_n),
            .wr(wr), 
            .rd(rd),

            .full(full),
            .empty(empty),

            .w_addr(w_addr),
            .r_addr(r_addr)
        );

endmodule


module fifo_ctrl_hyperbus #(parameter ADDR_WIDTH = 3)(
    input clk, reset_n,
    input wr, rd,

    output reg full, empty,

    output [ADDR_WIDTH - 1 : 0] w_addr,
    output [ADDR_WIDTH - 1 : 0] r_addr
    );

    //variable sequential
    reg [ADDR_WIDTH - 1 : 0] w_ptr, w_ptr_next;
    reg [ADDR_WIDTH - 1 : 0] r_ptr, r_ptr_next;
 
    reg full_next, empty_next;


    // sequential circuit
    always @(posedge clk, negedge reset_n) begin
        if(~reset_n)begin
            w_ptr <= 'b0;
            r_ptr <= 'b0;
            full <= 1'b0;
            empty <= 1'b1;
        end

        else begin
            w_ptr <= w_ptr_next;
            r_ptr <= r_ptr_next;
            full <= full_next;
            empty <= empty_next;
        end

    end

    //combi circuit
    always @(*)begin
        //default
        w_ptr_next = w_ptr;
        r_ptr_next = r_ptr;
        full_next = full;
        empty_next = empty;

        case ({wr, rd})
            2'b01: begin    //read
                if(~empty)begin
                    r_ptr_next = r_ptr + 1;
                    full_next = 1'b0;
                    if(r_ptr_next == w_ptr)begin
                        empty_next = 1'b1;
                    end
                end
            end

            2'b10: begin    //write
                if(~full)begin
                    w_ptr_next = w_ptr + 1;
                    empty_next = 1'b0;
                    if(w_ptr_next == r_ptr)begin
                        full_next = 1'b1;
                    end
                end
            end

            2'b11: begin    //read & write
                if(empty)begin
                    w_ptr_next = w_ptr;
                    r_ptr_next = r_ptr;
                end

                else begin
                    w_ptr_next = w_ptr + 1;
                    r_ptr_next = r_ptr + 1;
                end
            end

            default: ; // 2'b00
        endcase


    end

    //output
    assign w_addr = w_ptr;
    assign r_addr = r_ptr;

endmodule

module register_file_hyperbus #(parameter ADDR_WIDTH = 3, DATA_WIDTH = 8)(
    input clk,
    input w_en,

    input [ADDR_WIDTH - 1 : 0] r_addr, //reading address
    input [ADDR_WIDTH - 1 : 0] w_addr, //writing address

    input [DATA_WIDTH - 1 : 0] w_data, //writing data
    output [DATA_WIDTH - 1 : 0] r_data //reading data
    );

    //memory buffer
    reg [DATA_WIDTH -1 : 0] memory [0 : 2 ** ADDR_WIDTH - 1];

    //wire operation
    always @(posedge clk) begin
        if (w_en) memory[w_addr] <= w_data;
        
    end

    //read operation
    assign r_data = memory[r_addr];

endmodule


module edge_detector_hyperbus(
    input clk,
    input reset_n,
    input level_edge,
    
    output p_edge,
    output n_edge,
    output any_edge
    );
    
    //Edge detector mearly outputs
    
    reg state_reg, state_next;
    parameter S0 = 1'b0, S1 = 1'b1;
    
    //sequential state regs
    always @(posedge clk, negedge reset_n) begin
        if(~reset_n)
            state_reg <= S0;
        
        else
            state_reg <= state_next;
    end
    
    always @(*) begin
        case(state_reg)
            S0: begin
                if(level_edge)
                    state_next = S1;
                else
                    state_next = S0;
            end
            
            S1: begin
                if(level_edge)
                    state_next = S1;
                else
                    state_next = S0;
            end
            
            default: state_next = S0;   
        endcase
    end
    
    assign p_edge = (state_reg == S0) & level_edge;
    assign n_edge = (state_reg == S1) & ~level_edge;
    assign any_edge = p_edge | n_edge;
    
    
endmodule
