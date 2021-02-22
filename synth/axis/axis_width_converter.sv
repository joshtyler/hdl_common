// Copyright (C) 2021 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the
//  Open Hardware Description License, v. 1.0. If a copy
//  of the OHDL was not distributed with this file, You
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

`include "axis/axis.h"
`include "axis/utility.h"

module axis_width_converter
#(
	// Whilst it is normally a requirement, AXIS_I_BYTES and AXIS_O_BYTES don't need to be multiples of eachother
	parameter AXIS_I_BYTES = 1,
	parameter AXIS_O_BYTES = 2
) (
	input logic clk,
	input logic sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_I_BYTES),
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_O_BYTES)
);

localparam integer AXIS_W_BYTES = AXIS_I_BYTES > AXIS_O_BYTES? AXIS_I_BYTES : AXIS_O_BYTES;
localparam integer AXIS_N_BYTES = AXIS_I_BYTES > AXIS_O_BYTES? AXIS_O_BYTES : AXIS_I_BYTES;

localparam integer CTR_MAX = `INTEGER_DIV_CEIL(AXIS_W_BYTES, AXIS_N_BYTES);

localparam integer CTR_WIDTH = CTR_MAX == 1? 1 : $clog2(CTR_MAX);
// verilator lint_off WIDTH
localparam [CTR_WIDTH-1:0] CTR_HIGH = CTR_MAX-1;
//verilator lint_on WIDTH

logic [CTR_WIDTH-1:0] ctr;

// Use wide versions of the input and output data, so that we can always read and write without overflow
// Even when AXIS_W_BYTES / AXIS_N_BYTES isn't an exact multiple
logic [(CTR_MAX*AXIS_N_BYTES*8)-1:0] data_wide;
logic [(CTR_MAX*AXIS_N_BYTES)-1:0]   keep_wide;

// Simple pass through
generate
	if (AXIS_I_BYTES == AXIS_O_BYTES)
	begin
		assign axis_i_tready = axis_o_tready;
		assign axis_o_tvalid = axis_i_tvalid;
		assign axis_o_tlast = axis_i_tlast;
		assign axis_o_tkeep = axis_i_tkeep;
		assign axis_o_tdata = axis_i_tdata;
	end
endgenerate

// Split a big input word into many smaller output words
generate
	if (AXIS_I_BYTES > AXIS_O_BYTES) begin
		// Set the upper bits of keep_wide and data_wide to zero, lower bits to input data
		always_comb
		begin
			keep_wide = 0;
			data_wide = 0;
			data_wide[AXIS_I_BYTES*8-1:0] = axis_i_tdata;
			keep_wide[AXIS_I_BYTES-1:0]   = axis_i_tkeep;
		end

		assign axis_i_tready = ctr == CTR_HIGH? axis_o_tready : 1'b0;
		assign axis_o_tvalid = axis_i_tvalid;
		assign axis_o_tlast  = ctr == CTR_HIGH? axis_i_tlast : 1'b0;
		// verilator lint_off WIDTH
		assign axis_o_tkeep = keep_wide[(ctr+1)*(AXIS_O_BYTES)-1   -: (AXIS_O_BYTES)];
		assign axis_o_tdata = data_wide[(ctr+1)*(AXIS_O_BYTES*8)-1 -: (AXIS_O_BYTES*8)];
		// verilator lint_on WIDTH


		always @(posedge clk)
		begin
			if (sresetn == 0 || (axis_i_tready && axis_i_tvalid))
			begin
				ctr <= 0;
			end else begin
				// If we haven't sent out all of the data yet, increment the coutner
				if(axis_o_tready && axis_o_tvalid)
				begin
					ctr <= ctr + 1;
				end
			end
		end
	end
endgenerate

// Combine many small input words to make a big output word
generate
	if (AXIS_I_BYTES < AXIS_O_BYTES) begin
		assign axis_i_tready = 	ctr == CTR_HIGH? axis_o_tready : 1'b1;
		assign axis_o_tvalid = axis_i_tvalid && (axis_i_tlast || (ctr == CTR_HIGH)); // Finish early if we get the last beat early
		assign axis_o_tlast = axis_i_tlast;
		assign axis_o_tkeep = keep_wide[AXIS_O_BYTES-1:0];
		assign axis_o_tdata = data_wide[AXIS_O_BYTES*8-1:0];

		logic [(CTR_MAX*AXIS_N_BYTES*8)-1:0] data_wide_reg;
		logic [(CTR_MAX*AXIS_N_BYTES)-1:0]   keep_wide_reg;

		always_comb
		begin
			data_wide = data_wide_reg;
			keep_wide = keep_wide_reg;

			// verilator lint_off WIDTH
			data_wide[(ctr+1)*(AXIS_I_BYTES*8)-1 -: (AXIS_I_BYTES*8)] = axis_i_tdata;
			keep_wide[(ctr+1)*(AXIS_I_BYTES)-1   -: (AXIS_I_BYTES)] = axis_i_tkeep;
			// verilator lint_on WIDTH
		end

		always_ff @(posedge clk) data_wide_reg <= data_wide;

		always @(posedge clk)
		begin
			if (sresetn == 0 || (axis_o_tready && axis_o_tvalid))
			begin
				ctr <= 0;
				 keep_wide_reg <= 0;
			end else begin
				keep_wide_reg <= keep_wide;
				if(axis_i_tready && axis_i_tvalid)
				begin
					ctr <= ctr + 1;
				end
			end
		end
	end
endgenerate
endmodule
