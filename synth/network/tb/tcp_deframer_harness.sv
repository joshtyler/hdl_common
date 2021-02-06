
// Plumb through but with sideband signas as four bytes wide to appease C++

`include "axis/axis.h"

module tcp_deframer_harness
#(
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	input logic [15:0] axis_i_length_bytes,

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	output logic [31:0] axis_o_length_bytes = '0,
	output logic [31:0] axis_o_src_port = '0,
	output logic [31:0] axis_o_dst_port = '0,
	output logic [31:0] axis_o_seq_num,
	output logic [31:0] axis_o_ack_num,
	output logic [31:0] axis_o_ack = '0,
	output logic [31:0] axis_o_rst = '0,
	output logic [31:0] axis_o_syn = '0,
	output logic [31:0] axis_o_fin = '0,
	output logic [31:0] axis_o_window_size = '0
);

tcp_deframer deframer
(
	.clk(clk),
	.sresetn(sresetn),
	`AXIS_MAP_NO_USER(axis_i, axis_i),
	.axis_i_length_bytes(axis_i_length_bytes),
	`AXIS_MAP_NO_USER(axis_o, axis_o),
	.axis_o_length_bytes(axis_o_length_bytes[15:0]),
	.axis_o_src_port(axis_o_src_port[15:0]),
	.axis_o_dst_port(axis_o_dst_port[15:0]),
	.axis_o_seq_num(axis_o_seq_num),
	.axis_o_ack_num(axis_o_ack_num),
	.axis_o_ack(axis_o_ack[0]),
	.axis_o_rst(axis_o_rst[0]),
	.axis_o_syn(axis_o_syn[0]),
	.axis_o_fin(axis_o_fin[0]),
	.axis_o_window_size(axis_o_window_size[15:0])
);
endmodule
