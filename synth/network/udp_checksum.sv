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
	// Must be >= 2
	parameter AXIS_BYTES = 2
) (
	input clk,
	input sresetn,

	// Input data
	output logic        axis_i_tready,
	input  logic        axis_i_tvalid,
	input  logic        axis_i_tlast,
	input  logic [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input  logic        axis_o_tready,
	output logic        axis_o_tvalid,
	output logic [15:0] axis_o_csum
);

	// Accumulator, store the current checksum result. One bit wider for overflow bit
	logic [16:0] acc;

	assign axis_i_tready = (axis_o_tvalid == 0);

	// Add on final carry bit, and negate sum
	assign axis_o_csum = ~(acc[15:0] + {15'b0, acc[16]});

	always @(posedge clk) begin
		if (sresetn == 0 || (axis_o_tready && axis_o_tvalid)) begin
			axis_o_tvalid <= 0;
			acc <= 0;
		end else begin
			if(axis_i_tready && axis_i_tvalid)
			begin
				// Create 16 bit sum. Add on overflow bit from prevoius calculation
				acc <= axis_i_tdata + acc[15:0] + {15'b0, acc[16]};

				// If tlast was asserted, result will be valid on the next clock cycle
				if (axis_i_tlast) begin
					axis_o_tvalid <= 1;
				end
			end
		end
	end

endmodule
