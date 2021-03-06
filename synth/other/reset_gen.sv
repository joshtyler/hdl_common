// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

//Power on reset generator for Lattice iCE40
//Generates a synchronous reset for one period after reset
//en is an enable signal, e.g. from a PLL lock indicator

module reset_gen(clk, en, sreset);

parameter POLARITY = 1;
parameter COUNT = 100;

localparam integer CTR_WIDTH = $clog2(COUNT);

input clk, en;
output sreset;

//Lattice guarantees that all registers will contain 0 on power up
reg [CTR_WIDTH-1:0] ctr = 0;

always @(posedge clk)
	if(en)
	begin
		if(ctr != COUNT-1) //Halt on 10
			ctr <= ctr + 1'b1;
	end

if (POLARITY)
	assign sreset = !(ctr == COUNT-1); //Active high
else
	assign sreset = (ctr == COUNT-1); //Active low
endmodule
