// Create a UDP header
module udp_header_gen
#(
	localparam integer PORT_OCTETS = 2,
	localparam integer PROTOCOL_OCTETS = 1
) (
	input clk,
	input sresetn,

	// These inputs are set before sending any data
	// They should remain constant for a whole packet
	// It is likely that they will be set to constants
	input [(PORT_OCTETS*8)-1:0] src_port,
	input [(PORT_OCTETS*8)-1:0] dest_port,

	// The length input has an AXI stream interface
	// This allows it to easily be calculated and passed to the block on the fly
	output       payload_length_axis_tready,
	input        payload_length_axis_tvalid,
	input        payload_length_axis_tlast,
	input [15:0] payload_length_axis_tdata,

	input        axis_o_tready,
	output       axis_o_tvalid,
	output       axis_o_tlast,
	output [7:0] axis_o_tdata
);

logic       src_port_axis_tready;
logic       src_port_axis_tvalid;
logic       src_port_axis_tlast;
logic [7:0] src_port_axis_tdata;

logic       dst_port_axis_tready;
logic       dst_port_axis_tvalid;
logic       dst_port_axis_tlast;
logic [7:0] dst_port_axis_tdata;

logic       len_byte_wide_axis_tready;
logic       len_byte_wide_axis_tvalid;
logic       len_byte_wide_axis_tlast;
logic [7:0] len_byte_wide_axis_tdata;

logic       checksum_axis_tready;
logic       checksum_axis_tvalid;
logic       checksum_axis_tlast;
logic [7:0] checksum_axis_tdata;

vector_to_axis
#(
	.VEC_BYTES(PORT_OCTETS),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) src_port_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(src_port),

	.axis_tready(src_port_axis_tready),
	.axis_tvalid(src_port_axis_tvalid),
	.axis_tlast (src_port_axis_tlast),
	.axis_tdata (src_port_axis_tdata)
);

vector_to_axis
#(
	.VEC_BYTES(PORT_OCTETS),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) dst_port_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(dest_port),

	.axis_tready(dst_port_axis_tready),
	.axis_tvalid(dst_port_axis_tvalid),
	.axis_tlast (dst_port_axis_tlast),
	.axis_tdata (dst_port_axis_tdata)
);

// We don't actually implement checksum - it is optional for ipv4
vector_to_axis
#(
	.VEC_BYTES(2),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) checksum_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(16'h0000),

	.axis_tready(checksum_axis_tready),
	.axis_tvalid(checksum_axis_tvalid),
	.axis_tlast (checksum_axis_tlast),
	.axis_tdata (checksum_axis_tdata)
);

// Generate length axis. This includes the header, so we need to add that on to the payload
axis_width_converter
#(
	.AXIS_I_BYTES(2),
	.AXIS_O_BYTES(1),
	.MSB_FIRST(1)
) conv_length (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(payload_length_axis_tready),
	.axis_i_tvalid(payload_length_axis_tvalid),
	.axis_i_tlast (payload_length_axis_tlast),
	.axis_i_tdata (payload_length_axis_tdata + 8),

	.axis_o_tready(len_byte_wide_axis_tready),
	.axis_o_tvalid(len_byte_wide_axis_tvalid),
	.axis_o_tlast (len_byte_wide_axis_tlast),
	.axis_o_tdata (len_byte_wide_axis_tdata)
);

axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) output_joiner (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready({      checksum_axis_tready,
	                 len_byte_wide_axis_tready,
	                      dst_port_axis_tready,
	                      src_port_axis_tready}),

	.axis_i_tvalid({      checksum_axis_tvalid,
	                 len_byte_wide_axis_tvalid,
	                      dst_port_axis_tvalid,
	                      src_port_axis_tvalid}),

	.axis_i_tlast({       checksum_axis_tlast,
	                 len_byte_wide_axis_tlast,
	                      dst_port_axis_tlast,
	                      src_port_axis_tlast}),

	.axis_i_tdata({      checksum_axis_tdata,
                    len_byte_wide_axis_tdata,
                         dst_port_axis_tdata,
                         src_port_axis_tdata}),

	.axis_o_tready(axis_o_tready),
	.axis_o_tvalid(axis_o_tvalid),
	.axis_o_tlast (axis_o_tlast),
	.axis_o_tdata (axis_o_tdata)
);

endmodule
