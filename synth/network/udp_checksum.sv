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

`include "axis/utility.h"

module udp_checksum
#(
	// Must be 2 or 4 curently. Could expand if required.
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

	`STATIC_ASSERT((AXIS_BYTES == 2) || (AXIS_BYTES == 4));

	// Accumulator, store the current checksum result. One bit wider for overflow bit
	logic [16:0] acc;
	// Add on final carry bit, and negate sum
	// N.B. cannot overflow because worst cast in last cycle was 0xFFFF + 0xFFFF = 0x1FFFE
	// 0xFFFE + 0x1 = 0xFFFF - no overflow
	assign axis_o_csum = ~(acc[15:0] + {15'b0, acc[16]});

generate
if (AXIS_BYTES == 2)
begin
	assign axis_i_tready = (axis_o_tvalid == 0);
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
end else if (AXIS_BYTES == 4) begin
	// Accumulator for high half of word
	logic [16:0] acc_h;
	// Shreg for valid
	logic [2:0] axis_o_tvalid_shreg;
	// Block when we are calculating the output
	assign axis_i_tready = (axis_o_tvalid_shreg == 0);

	assign axis_o_tvalid = axis_o_tvalid_shreg[0];

	always @(posedge clk) begin
		if (sresetn == 0 || (axis_o_tready && axis_o_tvalid)) begin
			axis_o_tvalid_shreg <= 0;
			acc <= 0;
			acc_h <= 0;
		end else begin
			axis_o_tvalid_shreg <= {1'b0, axis_o_tvalid_shreg[2:1]};

			if(axis_i_tready && axis_i_tvalid)
			begin
				// Add sum for both halves of the data separately
				acc   <= axis_i_tdata[15:0]  + acc[15:0]   + {15'b0,   acc[16]};
				acc_h <= axis_i_tdata[31:16] + acc_h[15:0] + {15'b0, acc_h[16]};

				// If tlast was asserted, begin output process
				if (axis_i_tlast) begin
					axis_o_tvalid_shreg <= 3'b100;
				end
			end

			// Add on the overflow bit from each accumulator
			// N.B. can't overflow. See logic for axis_o_csum
			if(axis_o_tvalid_shreg == 3'b100)
			begin
				acc   <= acc[15:0]   + {15'b0,   acc[16]};
				acc_h <= acc_h[15:0] + {15'b0, acc_h[16]};
			end

			// Shrink the two checksums into one
			// N.B CAN overflow, but handled in axis_o_csum comb. logic
			if(axis_o_tvalid_shreg == 3'b010)
			begin
				acc <= acc+acc_h;
			end
		end
	end
end
endgenerate

endmodule
