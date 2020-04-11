// Copyright (C) 2020 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

module rom_to_axis
#(
	parameter AXIS_BYTES = 1,
	parameter DEPTH = 2,
	parameter [DEPTH*AXIS_BYTES*8-1:0] MEM = '0
) (
	input logic  clk,
	input logic  sresetn,

	// Output
	input  logic                      axis_tready,
	output logic                      axis_tvalid,
	output logic                      axis_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_tdata
);

logic [$clog2(DEPTH)-1:0] ctr, next_ctr;
logic done;

always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		done <= 0;
	end else begin
		if(axis_tready && axis_tvalid) begin
			if(axis_tlast) begin
				done <= 1;
			end
		end
	end

	ctr <= next_ctr;
	axis_tdata <= MEM[8*next_ctr +: 8];
end

always_comb
begin
	next_ctr = ctr;
	if(!sresetn) begin
		next_ctr = 0;
	end else if(axis_tready && axis_tvalid) begin
		next_ctr = ctr + 1;
	end
end

assign axis_tvalid = sresetn && (!done);
assign axis_tlast = ctr == (DEPTH-1);


endmodule
