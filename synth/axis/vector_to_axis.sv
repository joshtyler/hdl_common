// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Repeatedly output a byte vector as an AXI stream
// This could be replaced with axis_width converter at some point...

module vector_to_axis
#(
	parameter VEC_BYTES = 1,
	parameter AXIS_BYTES = 1,
	parameter MSB_FIRST = 0
) (
	input clk,
	input sresetn,

	input [(VEC_BYTES*8)-1:0] vec,

	// Output
	input                              axis_tready,
	output logic                       axis_tvalid,
	output logic                       axis_tlast,
	output logic  [(AXIS_BYTES*8)-1:0] axis_tdata
);

// The vector must be a multiple of AXIS_BYTES
//assert VEC_BYTES % AXIS_BYTES = 0;

localparam integer CTR_MAX = (VEC_BYTES/AXIS_BYTES) -1;

localparam integer CTR_WIDTH = CTR_MAX == 0? 1 : $clog2(CTR_MAX +1);

logic [CTR_WIDTH-1:0] ctr;
/* verilator lint_off WIDTH */
localparam [CTR_WIDTH-1:0] CTR_INIT = MSB_FIRST? CTR_MAX : 0;
localparam [CTR_WIDTH-1:0] CTR_LAST = MSB_FIRST? 0       : CTR_MAX;
/* verilator lint_on WIDTH */

always @(posedge clk)
begin
	if (sresetn == 0)
	begin
		ctr <= CTR_INIT;
	end else begin
		if (axis_tready == 1)
		begin
			if (ctr == CTR_LAST)
			begin
				ctr <= CTR_INIT;
			end else begin
				if(MSB_FIRST)
					ctr <= ctr - 1;
				else
					ctr <= ctr + 1;
			end
		end
	end
end

assign axis_tvalid = sresetn; // Valid whenver not in reset
assign axis_tlast = (ctr == CTR_LAST);

assign axis_tdata = vec[ ((ctr+1)*AXIS_BYTES*8)-1 -: AXIS_BYTES*8];



endmodule
