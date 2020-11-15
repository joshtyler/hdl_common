
// Plumb through but with sideband signas as four bytes wide to appease C++

`include "axis.h"

module ip_deframer_harness
#(
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	output logic [31:0] axis_o_length = '0,
	output logic [31:0]  axis_o_protocol = '0,
	output logic [31:0] axis_o_src_ip,
	output logic [31:0] axis_o_dst_ip
);

ip_deframer deframer
(
	.clk(clk),
	.sresetn(sresetn),
	`AXIS_MAP_NO_USER(axis_i, axis_i),
	`AXIS_MAP_NO_USER(axis_o, axis_o),
	.axis_o_length(axis_o_length[15:0]),
	.axis_o_protocol(axis_o_protocol[7:0]),
	.axis_o_src_ip(axis_o_src_ip),
	.axis_o_dst_ip(axis_o_dst_ip)
);
endmodule
