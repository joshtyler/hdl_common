// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// UDP Checksum algorithm
// "Checksum is the 16-bit one's complement
// of the one's complement sum of a pseudo header of information from
// the IP header, the UDP header, and the data,
// padded with zero octets at the end (if necessary) to make a multiple of two octets"

// This module takes the data in two bytes at a time
// And data is output two bytes at a time

module udp_checksum
#(
	parameter AXIS_BYTES = 2,
	parameter MSB_FIRST = 0
) (
	input logic clk,
	input logic sresetn,

	// Input
	output logic                      axis_i_tready,
	input  logic                      axis_i_tvalid,
	input  logic                      axis_i_tlast,
	input  logic [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input  logic                      axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic                      axis_o_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_o_tdata
);

	logic        axis_i_conv_tready;
	logic        axis_i_conv_tvalid;
	logic        axis_i_conv_tlast;
	logic [15:0] axis_i_conv_tdata;

	logic        axis_o_conv_tready;
	logic        axis_o_conv_tvalid;
	logic        axis_o_conv_tlast;
	logic [15:0] axis_o_conv_tdata;

	axis_width_converter
	#(
		.AXIS_I_BYTES(AXIS_BYTES),
		.AXIS_O_BYTES(2),
		.MSB_FIRST(MSB_FIRST)
	) conv_i (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_i_tready),
		.axis_i_tvalid(axis_i_tvalid),
		.axis_i_tlast (axis_i_tlast),
		.axis_i_tdata (axis_i_tdata),

		.axis_o_tready(axis_i_conv_tready),
		.axis_o_tvalid(axis_i_conv_tvalid),
		.axis_o_tlast (axis_i_conv_tlast),
		.axis_o_tdata (axis_i_conv_tdata)
	);

	udp_checksum_two_bytes checksum (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_i_conv_tready),
		.axis_i_tvalid(axis_i_conv_tvalid),
		.axis_i_tlast (axis_i_conv_tlast),
		.axis_i_tdata (axis_i_conv_tdata),

		.axis_o_tready(axis_o_conv_tready),
		.axis_o_tvalid(axis_o_conv_tvalid),
		.axis_o_tlast (axis_o_conv_tlast),
		.axis_o_tdata (axis_o_conv_tdata)
	);

	axis_width_converter
	#(
		.AXIS_I_BYTES(2),
		.AXIS_O_BYTES(AXIS_BYTES),
		.MSB_FIRST(MSB_FIRST)
	) conv_o (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_o_conv_tready),
		.axis_i_tvalid(axis_o_conv_tvalid),
		.axis_i_tlast (axis_o_conv_tlast),
		.axis_i_tdata (axis_o_conv_tdata),

		.axis_o_tready(axis_o_tready),
		.axis_o_tvalid(axis_o_tvalid),
		.axis_o_tlast (axis_o_tlast),
		.axis_o_tdata (axis_o_tdata)
	);

endmodule

module udp_checksum_two_bytes(
	input clk,
	input sresetn,

	// Input
	output logic        axis_i_tready,
	input  logic        axis_i_tvalid,
	input  logic        axis_i_tlast,
	input  logic [15:0] axis_i_tdata,

	// Output
	input  logic        axis_o_tready,
	output logic        axis_o_tvalid,
	output logic        axis_o_tlast,
	output logic [15:0] axis_o_tdata
);

	// Accumulator, store the current checksum result. One bit wider for overflow bit
	logic [16:0] acc;

	logic [1:0] state;
	localparam SM_RESET = 2'b00;
	localparam SM_CALC = 2'b01;
	localparam SM_DONE = 2'b10;

	assign axis_i_tready = (state == SM_CALC);
	assign axis_o_tlast = 1;
	assign axis_o_tdata = ~acc[15:0];

	always @(posedge clk) begin
		if (sresetn == 0) begin
			state <= SM_RESET;
			axis_o_tvalid <= 0;
		end else begin
			case(state)
				SM_RESET: begin
					// We can proceed if the current result has been accepted
					// Or unconditoinally if the result is not valid (we have been reset)
					if((axis_o_tvalid && axis_o_tready) || !axis_o_tvalid) begin
						state <= SM_CALC;
						axis_o_tvalid <= 0;
						acc <= 0;
					end
				end
				SM_CALC : begin
					if(axis_i_tready && axis_i_tvalid) begin
						// Create 16 bit sum. Add on overflow bit from prevoius calculation
						/*verilator lint_off WIDTH */
						acc <= axis_i_tdata + acc[15:0] + acc[16];
						/*verilator lint_on WIDTH */
						if (axis_i_tlast) begin
							state <= SM_DONE;
						end
					end
				end
				SM_DONE : begin
					// Add on final overflow bit and signal that output is valid
					/*verilator lint_off WIDTH */
					acc <= acc[15:0] + acc[16];
					/*verilator lint_on WIDTH */
					state <= SM_RESET;
					axis_o_tvalid <= 1;
				end
				default: state <= SM_RESET;
			endcase
		end
	end

endmodule
