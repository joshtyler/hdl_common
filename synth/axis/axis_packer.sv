// Copyright (C) 2020 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the
//  Open Hardware Description License, v. 1.0. If a copy
//  of the OHDL was not distributed with this file, You
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

`include "axis/axis.h"


// Remove NULL bytes from an AXI stream
// I.E tkeep will be all ones
// First we align incoming words so that the valid bytes are packed at the bottom
	// This is handled in several stages for timing reasons
// Then we combine words to pack the output

// N.B. The case where last is signalled on an entirely NULL word is not currently handled!

module axis_packer
#(
	parameter AXIS_BYTES = 2
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES)
);

// We need a pack stage for each bit in tkeep (less one)
// veri gets confused and thinks there is circular logic here, even though there isn't...
// Hence the lint_off
/* verilator lint_off UNOPTFLAT */
`AXIS_MULTI_INST_NO_USER(axis_aligning, AXIS_BYTES, AXIS_BYTES);
/* verilator lint_on UNOPTFLAT */

assign axis_i_tready = axis_aligning_tready[0];
assign axis_aligning_tvalid[0] = axis_i_tvalid;
assign axis_aligning_tlast [0] = axis_i_tlast;
assign axis_aligning_tkeep [(0+1)*AXIS_BYTES-1   -: AXIS_BYTES] = axis_i_tkeep;
assign axis_aligning_tdata [(0+1)*AXIS_BYTES*8-1 -: AXIS_BYTES*8] = axis_i_tdata;

generate
	genvar i;
	for(i=0; i<AXIS_BYTES-1; i++)
	begin
		axis_packer_align_stage
		#(
			.AXIS_BYTES(AXIS_BYTES),
			.BYTES_TO_IGNORE(i)
		) align_stage (
			.clk(clk),
			.sresetn(sresetn),

			.axis_i_tready(axis_aligning_tready[i]),
			.axis_i_tvalid(axis_aligning_tvalid[i]),
			.axis_i_tlast (axis_aligning_tlast [i]),
			.axis_i_tkeep (axis_aligning_tkeep [(i+1)*AXIS_BYTES-1 -: AXIS_BYTES]),
			.axis_i_tdata (axis_aligning_tdata [(i+1)*AXIS_BYTES*8-1 -: AXIS_BYTES*8]),

			.axis_o_tready(axis_aligning_tready[i+1]),
			.axis_o_tvalid(axis_aligning_tvalid[i+1]),
			.axis_o_tlast (axis_aligning_tlast [i+1]),
			.axis_o_tkeep (axis_aligning_tkeep [(i+1+1)*AXIS_BYTES-1 -: AXIS_BYTES]),
			.axis_o_tdata (axis_aligning_tdata [(i+1+1)*AXIS_BYTES*8-1 -: AXIS_BYTES*8])
		);
	end
endgenerate


axis_packer_combine_stage
#(
	.AXIS_BYTES(AXIS_BYTES)
) combine_stage (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_aligning_tready[AXIS_BYTES-1]),
	.axis_i_tvalid(axis_aligning_tvalid[AXIS_BYTES-1]),
	.axis_i_tlast (axis_aligning_tlast [AXIS_BYTES-1]),
	.axis_i_tkeep (axis_aligning_tkeep [(AXIS_BYTES-1+1)*AXIS_BYTES-1   -: AXIS_BYTES]),
	.axis_i_tdata (axis_aligning_tdata [(AXIS_BYTES-1+1)*AXIS_BYTES*8-1 -: AXIS_BYTES*8]),

	`AXIS_MAP_NO_USER(axis_o, axis_o)
);

endmodule

// Conditionally shift each byte in a word by one place
// We therefore need AXIS_BYTES such stages
// Find where to start shifting by the position of the lowest zero in tkeep
// N.B. for each subsequent stage, we can ignore the one more byte from the top
// This is because it will either be zero, or set in position
// This simplifies logic sligtly
module axis_packer_align_stage
#(
	parameter AXIS_BYTES = 2,
	parameter BYTES_TO_IGNORE = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES)
);

	// Find index of lowest zero
	// If no zeros, set to all ones
	// This is why we need to be one bit wider than the clog2 range
	function [$clog2(AXIS_BYTES):0] find_lowest_zero;
		input [AXIS_BYTES-1:0] word;
		integer i;
		begin
			find_lowest_zero = '1;
			for(i=AXIS_BYTES-1; i>=0; i=i-1)
			begin
				if(word[i] == 0)
				begin
					find_lowest_zero = i[$clog2(AXIS_BYTES):0];
				end
			end
		end
	endfunction

	logic [$clog2(AXIS_BYTES):0] lowest_zero_in_tkeep;
	assign lowest_zero_in_tkeep = find_lowest_zero(axis_i_tkeep);

	// Do the shifting for each byte
	// We are effectively baking in a register stage here
	// We could do combinatorially, and have a separate reg stage
	// but writing like this probably gives the synthesis engine the best chance
	always_ff @(posedge clk)
	begin
		if(sresetn == 0 || axis_o_tready)
		begin
			axis_o_tvalid <= 0;
		end

		if (axis_i_tready && axis_i_tvalid)
		begin
			axis_o_tvalid <= 1;
			axis_o_tlast <= axis_i_tlast;
		end
	end
	assign axis_i_tready = (!axis_o_tvalid) || axis_o_tready;

	// For all the other bytes do our shifting logic
	generate
		genvar i;
		for(i=0; i<AXIS_BYTES; i++)
		begin
			always_ff @(posedge clk)
			begin
				if(axis_i_tready && axis_i_tvalid)
				begin
					// Keep same value by default
					axis_o_tdata[(i+1)*8-1 -: 8] <= axis_i_tdata[(i+1)*8-1 -: 8];
					axis_o_tkeep[i] <= axis_i_tkeep[i];

					// Shift if we are eligible
					if(i < AXIS_BYTES-BYTES_TO_IGNORE) // Constant
					begin
						if(i >= lowest_zero_in_tkeep)
						begin
							if(i == AXIS_BYTES-BYTES_TO_IGNORE-1) // Constant
							begin
								// The top is a special case - explicitly shift in zeros
								axis_o_tdata[(i+1)*8-1 -: 8] <= 0;
								axis_o_tkeep[i]            <= 0;
							end else begin
								/* verilator lint_off SELRANGE */ // veri can't figure out that this won't be generated for the top bit
								axis_o_tdata[(i+1)*8-1 -: 8] <= axis_i_tdata[(i+2)*8-1 -: 8];
								axis_o_tkeep[i]            <= axis_i_tkeep[i+1];
								/* verilator lint_on SELRANGE */
							end
						end
					end
				end
			end
		end
	endgenerate
endmodule

// Combine multiple (least significant byte aligned) words into one
// Assemble partial words into a register and present to the user
module axis_packer_combine_stage
#(
	parameter AXIS_BYTES = 2
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES)
);
	// The data is valid when the register contains last, or is fully packed
	assign axis_o_tvalid = axis_o_tlast || (axis_o_tkeep == '1);

	// Transfer the last to the output register when we accept an input that asserted last
	always_ff @(posedge clk)
	begin
		if(sresetn == 0)
		begin
			axis_o_tlast <= 0;
		end else begin
			if(axis_o_tready && axis_o_tvalid)
			begin
				axis_o_tlast <= 0;
			end

			if (axis_i_tready && axis_i_tvalid)
			begin
				axis_o_tlast <= axis_i_tlast;
			end
		end
	end

	logic able_to_write_to_register;
	// We can write to the register when we are not asserting it as valid, or we are asserting it as valid, but downstream is simultaneously accepting it
	assign able_to_write_to_register = (!axis_o_tvalid) || (axis_o_tready && axis_o_tvalid);

	logic [$clog2(AXIS_BYTES)-1:0] input_base_index;

	logic [$clog2(AXIS_BYTES+1)-1:0] num_bytes_in_reg, num_bytes_in_incoming, num_spaces_for_write, bytes_consumed_from_incoming;
	//logic signed [$clog2(AXIS_BYTES+1):0] leftover_bytes_from_incoming;

	assign num_bytes_in_reg = $countones(axis_o_tkeep);
	assign num_bytes_in_incoming = $countones(axis_i_tkeep);
	assign num_spaces_for_write = axis_o_tvalid? AXIS_BYTES : $countones(~axis_o_tkeep);

	// The number of leftover bytes is the number of bytes in the incoming - number of spaces in the reg
	// If this is zero or negative, they all fitted
	//assign leftover_bytes_from_incoming = (num_bytes_in_incoming - (AXIS_BYTES - num_bytes_in_reg));

	// Only correct when input_base_index == 0
	assign bytes_consumed_from_incoming = (num_bytes_in_incoming < num_spaces_for_write) ? num_bytes_in_incoming : num_spaces_for_write; // This is effectively min()

	// Accept input data when we can write it to the register and the entirity of what we are writing fits
	// This is eiter if there is enough room, or the output register is empty, and we are filling up our leftover
	assign axis_i_tready = able_to_write_to_register &&  ((bytes_consumed_from_incoming == num_bytes_in_incoming) || (input_base_index > 0));

	always_ff @(posedge clk)
	begin
		if(sresetn == 0)
		begin
			input_base_index <= 0;
		end else begin
			// If the input is valid, we can use it to populate the register, either partially or entirely
			if (axis_i_tvalid && able_to_write_to_register)
			begin
				if(axis_i_tready) //(input_base_index > 0)
				begin
					// If we started with an empty register, we dumped the whole input in
					input_base_index <= 0;
				end else begin
					// If something is left over set input_base_index to start off from there
					input_base_index <= bytes_consumed_from_incoming[$clog2(AXIS_BYTES)-1:0];
				end
			end
		end
	end

	// We need to do this in a for generate becuase we can't variable slice in verilog
	generate
		genvar i;
		for(i=0; i<AXIS_BYTES; i++)
		begin
			always_ff @(posedge clk)
			begin
				if(sresetn == 0)
				begin
					axis_o_tkeep[i] <= 0;
				end else begin

					if(axis_o_tready && axis_o_tvalid)
					begin
						axis_o_tkeep[i] <= 0;
					end

					if(axis_i_tvalid && able_to_write_to_register) begin
						if(axis_o_tvalid)
						begin
							// N.B We are not necessarily reading from the bottom of the input word
							if(i >= input_base_index)
							begin
								axis_o_tkeep[  (i-input_base_index)] <= axis_i_tkeep[i];
								/* verilator lint_off WIDTH */
								//axis_o_tdata[(((i-input_base_index)+1)*8)-1 -: 8] <= axis_i_tdata[((i+1)*8)-1 -: 8];
								/* verilator lint_on WIDTH */
							end
						end else begin
							// The output register may be partially full, fill up from where we got to
							// N.B. In this situation we are always starting at the bottom of the input word
							// This is because if we had spare bytes from the input word, we would have flushed the output, resulting in the register being empty
						 	if(i < (AXIS_BYTES-num_bytes_in_reg))
							begin
								axis_o_tkeep[  (num_bytes_in_reg+i)] <= axis_i_tkeep[i];
								axis_o_tdata[ num_bytes_in_reg*8 + ((i+1)*8) -1 -: 8] <= axis_i_tdata[((i+1)*8)-1 -: 8];
							end
						end
					end
				end
			end
		end
	endgenerate
endmodule
