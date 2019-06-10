// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// For now this is just a very simple counter, perhaps expand in the future

module axis_counter
#(
	parameter AXIS_BYTES = 1
) (
	input clk,
	input sresetn,

	// Output
	input                             axis_tready,
	output                            axis_tvalid,
	output                            axis_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_tdata
);

	assign axis_tvalid = 1;
	assign axis_tlast = 1;

	always @(posedge clk)
		if (sresetn == 0)
			axis_tdata <= 0;
		else
			if (axis_tready && axis_tvalid)
				axis_tdata <= axis_tdata+1;

endmodule
