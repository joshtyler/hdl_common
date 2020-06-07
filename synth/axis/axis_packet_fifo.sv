// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

module axis_packet_fifo
#(
	parameter AXIS_BYTES = 1,
	parameter LOG2_DEPTH = 10
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

// The desired behaviour is only to allow data to leave the FIFO when the FIFO
// contains at least one whole packet to read out
// The only exception to this is if the FIFO is full
// In this case the FIFO should let data out anyway
// (N.B in this fill up scenario, the FIFO should keep letting data out until all of that packet is out)

// In order to do this, we just need to count the number of tlasts in the FIFO
// If there is at least one in there let data out, otherwise block

// The maximum number of tlasts that can be in the FIFO is the same as the depth of the FIFO
// This counter needs to be one bit wider than that in case the FIFO is absolutely full of tlasts
// E.g. a 2^10=1024 deep FIFO can store 1024 tlasts, so we need an 11 bit counter
logic [LOG2_DEPTH :0] tlast_ctr;

logic packet_written, packet_read;
assign packet_written = axis_i_tready && axis_i_tvalid && axis_i_tlast;
assign packet_read = axis_o_tready && axis_o_tvalid && axis_o_tlast;

logic                      axis_o_gate_tready;
logic                      axis_o_gate_tvalid;
logic                      axis_o_gate_tlast;
logic [(AXIS_BYTES*8)-1:0] axis_o_gate_tdata;

always @(posedge clk)
	if(sresetn == 0) begin
		tlast_ctr <= 0;
	end else begin
		// If we've written, and not read, we are net +1
		if (packet_written && !packet_read) begin
			tlast_ctr <= tlast_ctr + 1;
		// If we've read and not written, we are net -1
		end else if (!packet_written && packet_read) begin
			tlast_ctr <= tlast_ctr - 1;
			//assert (tlast_ctr != 0);
		end
		// Otherwise there is no change
	end


axis_fifo #(
		.AXIS_BYTES(AXIS_BYTES),
		.LOG2_DEPTH(LOG2_DEPTH)
	) fifo_inst (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_i_tready),
		.axis_i_tvalid(axis_i_tvalid),
		.axis_i_tlast (axis_i_tlast),
		.axis_i_tdata (axis_i_tdata),
		.axis_i_tuser(1'b1),

		.axis_o_tready(axis_o_gate_tready),
		.axis_o_tvalid(axis_o_gate_tvalid),
		.axis_o_tlast (axis_o_gate_tlast),
		.axis_o_tdata (axis_o_gate_tdata),
		.axis_o_tuser()
	);

logic axis_gater_c_pass;
assign axis_gater_c_pass = (| tlast_ctr) || (!axis_i_tready);

axis_gater #(
		.AXIS_BYTES(AXIS_BYTES),
		.PACKET_WISE(1)
	) gater (
		.clk(clk),
		.sresetn(sresetn),

		// Allow stream to pass if at least one tlast in FIFO
		// Or FIFO is full
		// We can ignore c_ready, as we can just let the gater sample c_pass when it wants
		.c_ready(),
		.c_pass(axis_gater_c_pass),

		.axis_i_tready(axis_o_gate_tready),
		.axis_i_tvalid(axis_o_gate_tvalid),
		.axis_i_tlast (axis_o_gate_tlast),
		.axis_i_tdata (axis_o_gate_tdata),

		.axis_o_tready(axis_o_tready),
		.axis_o_tvalid(axis_o_tvalid),
		.axis_o_tlast (axis_o_tlast),
		.axis_o_tdata (axis_o_tdata)
	);

endmodule
