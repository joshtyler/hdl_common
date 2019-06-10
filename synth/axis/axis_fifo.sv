// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

module axis_fifo
#(
	parameter AXIS_BYTES = 1,
	parameter DEPTH = 1024
) (
	input clk,
	input sresetn,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input                       axis_o_tready,
	output                      axis_o_tvalid,
	output                      axis_o_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o_tdata
);

logic                      axis_o_buf_tready;
logic                      axis_o_buf_tvalid;
logic                      axis_o_buf_tlast;
logic [(AXIS_BYTES*8)-1:0] axis_o_buf_tdata;

logic full,empty;

assign axis_i_tready = !full;
// valid lags one cycle behind empty
// This is because empty is a "ready to accept reads" signal
// So the data is valid one clock cycle after it goes low
// And when it goes high again, the data is in fact valid!
always @(posedge clk) begin
	if(sresetn == 0) begin
		axis_o_buf_tvalid <= 0;
	end else begin
		if(axis_o_buf_tready) begin
			axis_o_buf_tvalid <= !empty;
		end
	end
end
fifo
	#(
		.WIDTH((AXIS_BYTES*8)+1),
		.DEPTH(DEPTH)
	) fifo_inst (
		.clk(clk),
		.n_reset(sresetn),

		.full(full),
		.wr_en(axis_i_tvalid),
		.data_in ({axis_i_tdata, axis_i_tlast}),

		.rd_en(axis_o_buf_tready),
		.empty(empty),
		.data_out ({axis_o_buf_tdata, axis_o_buf_tlast})
	);

axis_register
	#(
		.AXIS_BYTES(1)
	) register (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_o_buf_tready),
		.axis_i_tvalid(axis_o_buf_tvalid),
		.axis_i_tlast (axis_o_buf_tlast),
		.axis_i_tdata (axis_o_buf_tdata),

		.axis_o_tready(axis_o_tready),
		.axis_o_tvalid(axis_o_tvalid),
		.axis_o_tlast (axis_o_tlast),
		.axis_o_tdata (axis_o_tdata)
	);

endmodule
