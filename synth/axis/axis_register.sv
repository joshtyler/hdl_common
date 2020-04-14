// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the
//  Open Hardware Description License, v. 1.0. If a copy
//  of the OHDL was not distributed with this file, You
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

module axis_register
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_USER_BITS  = 1
) (
	input clk,
	input sresetn,

	// Input
	output logic                      axis_i_tready,
	input  logic                      axis_i_tvalid,
	input  logic                      axis_i_tlast,
	input  logic [(AXIS_BYTES*8)-1:0] axis_i_tdata,
	input  logic [AXIS_USER_BITS-1:0] axis_i_tuser ,//= '0,

	// Output
	input  logic                      axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic                      axis_o_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_o_tdata,
	output logic [AXIS_USER_BITS-1:0] axis_o_tuser
);
	// We are able to store data when the register is empty
	// Or we are also clocking data out
	assign axis_i_tready = (!axis_o_tvalid) || axis_o_tready;

	always @(posedge clk)
	begin
		if (sresetn == 0)
		begin
			axis_o_tvalid <= 0;
		end else begin
			if (axis_i_tready && axis_i_tvalid)
			begin
				// Fill the register if we are able
				axis_o_tvalid <= axis_i_tvalid;
				axis_o_tlast <= axis_i_tlast;
				axis_o_tdata <= axis_i_tdata;
				axis_o_tuser <= axis_i_tuser;
			end else if (axis_o_tready)
			begin
				// If we are reading and not writing, invalidate the register
				axis_o_tvalid <= 0;
			end
		end
	end

endmodule
