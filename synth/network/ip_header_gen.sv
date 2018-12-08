// Create an IPv4 header

// Note this is a basic implementation:
	// IHL is fixed, therefore options is not supported
	// Identification is not supported
	// Fragmentation is not supported

// Structure:
/*

{oct0:1, length, oct4:8, protocol} --> joiner --> broadcaster --------------------------> joiner ---> output
                                                         |                                 |   |
                                                          --> joiner --> checksum --> fifo --  |
                                                                |                              |
                                                       ip --> switch---------------------------
*/

module ip_header_gen
#(
	localparam integer IP_ADDR_OCTETS = 4,
	localparam integer PROTOCOL_OCTETS = 1
) (
	input clk,
	input sresetn,

	// These inputs are set before sending any data
	// They should remain constant for a whole packet
	// It is likely that they will be set to constants
	input [(IP_ADDR_OCTETS*8)-1:0] src_ip,
	input [(IP_ADDR_OCTETS*8)-1:0] dest_ip,
	input [(PROTOCOL_OCTETS*8)-1:0] protocol,

	// The length input has an AXI stream interface
	// This allows it to easily be calculated and passed to the block on the fly
	output       payload_length_axis_tready,
	input        payload_length_axis_tvalid,
	input        payload_length_axis_tlast,
	input [15:0] payload_length_axis_tdata,

	input axis_o_tready,
	output axis_o_tvalid,
	output axis_o_tlast,
	output [7:0] axis_o_tdata
);

// Octets 0:1, and 4:8 are constant in this implementation
// Therefore we can get away with hardcoding it
// See https://en.wikipedia.org/wiki/IPv4#Header to decode
localparam OCTETS_0_TO_1 = 16'h4500;
// Total length goes here
//localparam OCTETS_4_TO_8 = 40'h00004000FF;
localparam OCTETS_4_TO_8 = 40'hA86C400040; //Add identification to match test packet
// Protocol goes here
// Checksum goes here
// Source IP goes here
// Destination IP goes here

logic       octets0to1_axis_tready;
logic       octets0to1_axis_tvalid;
logic       octets0to1_axis_tlast;
logic [7:0] octets0to1_axis_tdata;

logic       len_byte_wide_axis_tready;
logic       len_byte_wide_axis_tvalid;
logic       len_byte_wide_axis_tlast;
logic [7:0] len_byte_wide_axis_tdata;

logic       octets4to8_axis_tready;
logic       octets4to8_axis_tvalid;
logic       octets4to8_axis_tlast;
logic [7:0] octets4to8_axis_tdata;

logic       input_joined_axis_tready;
logic       input_joined_axis_tvalid;
logic       input_joined_axis_tlast;
logic [7:0] input_joined_axis_tdata;

logic       main_out_axis_tready;
logic       main_out_axis_tvalid;
logic       main_out_axis_tlast;
logic [7:0] main_out_axis_tdata;

logic       main_checksum_axis_tready;
logic       main_checksum_axis_tvalid;
logic       main_checksum_axis_tlast;
logic [7:0] main_checksum_axis_tdata;

logic       ip_axis_tready;
logic       ip_axis_tvalid;
logic       ip_axis_tlast;
logic [7:0] ip_axis_tdata;

logic       ip_axis_checksum_tready;
logic       ip_axis_checksum_tvalid;
logic       ip_axis_checksum_tlast;
logic [7:0] ip_axis_checksum_tdata;

logic       ip_axis_out_tready;
logic       ip_axis_out_tvalid;
logic       ip_axis_out_tlast;
logic [7:0] ip_axis_out_tdata;

logic       checksum_in_axis_tready;
logic       checksum_in_axis_tvalid;
logic       checksum_in_axis_tlast;
logic [7:0] checksum_in_axis_tdata;

logic       checksum_out_axis_tready;
logic       checksum_out_axis_tvalid;
logic       checksum_out_axis_tlast;
logic [7:0] checksum_out_axis_tdata;

logic       checksum_fifoed_axis_tready;
logic       checksum_fifoed_axis_tvalid;
logic       checksum_fifoed_axis_tlast;
logic [7:0] checksum_fifoed_axis_tdata;

logic       ip_checksum_axis_tready;
logic       ip_checksum_axis_tvalid;
logic       ip_checksum_axis_tlast;
logic [7:0] ip_checksum_axis_tdata;

logic       axis_ip_tready;
logic       axis_ip_tvalid;
logic       axis_ip_tlast;
logic [7:0] axis_ip_tdata;

logic       ip_out_axis_tready;
logic       ip_out_axis_tvalid;
logic       ip_out_axis_tlast;
logic [7:0] ip_out_axis_tdata;

// Vector to axis for input
vector_to_axis
#(
	.VEC_BYTES(2),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) oct_0_to_1_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(OCTETS_0_TO_1),

	.axis_tready(octets0to1_axis_tready),
	.axis_tvalid(octets0to1_axis_tvalid),
	.axis_tlast (octets0to1_axis_tlast),
	.axis_tdata (octets0to1_axis_tdata)
);

vector_to_axis
#(
	.VEC_BYTES(5),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) oct_4_to_8_axis (
	.clk(clk),
	.sresetn(sresetn),

	.vec(OCTETS_4_TO_8),

	.axis_tready(octets4to8_axis_tready),
	.axis_tvalid(octets4to8_axis_tvalid),
	.axis_tlast (octets4to8_axis_tlast),
	.axis_tdata (octets4to8_axis_tdata)
);

// Generate length axis. This includes the header, so we need to add that on to the payload
// Our header doesn't have options, so is a fixed 20 bytes
localparam [15:0] IP_HEADER_LEN = 20;

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
	.axis_i_tdata (payload_length_axis_tdata + IP_HEADER_LEN),

	.axis_o_tready(len_byte_wide_axis_tready),
	.axis_o_tvalid(len_byte_wide_axis_tvalid),
	.axis_o_tlast (len_byte_wide_axis_tlast),
	.axis_o_tdata (len_byte_wide_axis_tdata)
);

// Join inputs together
logic prot_axis_tready; // Dummy signal, ignored
logic one = 1; // vlator doesn't handle constants in concatenation properly?
axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(4)
) input_joiner (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready({          prot_axis_tready,
	                    octets4to8_axis_tready,
	                 len_byte_wide_axis_tready,
	                    octets0to1_axis_tready}),

	.axis_i_tvalid({                       one,
	                    octets4to8_axis_tvalid,
	                 len_byte_wide_axis_tvalid,
	                    octets0to1_axis_tvalid}),

	.axis_i_tlast ({                      one,
	                    octets4to8_axis_tlast,
	                 len_byte_wide_axis_tlast,
	                    octets0to1_axis_tlast}),

	.axis_i_tdata ({                 protocol,
	                    octets4to8_axis_tdata,
	                 len_byte_wide_axis_tdata,
	                    octets0to1_axis_tdata}),

.axis_o_tready(input_joined_axis_tready),
.axis_o_tvalid(input_joined_axis_tvalid),
.axis_o_tlast (input_joined_axis_tlast),
.axis_o_tdata (input_joined_axis_tdata)
);

// Distribute first past of message to checksum and output
axis_broadcaster
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(2)
) in_bcaster (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(input_joined_axis_tready),
	.axis_i_tvalid(input_joined_axis_tvalid),
	.axis_i_tlast (input_joined_axis_tlast),
	.axis_i_tdata (input_joined_axis_tdata),

	.axis_o_tready({      main_out_axis_tready,
	                 main_checksum_axis_tready}),
	.axis_o_tvalid({      main_out_axis_tvalid,
	                 main_checksum_axis_tvalid}),
	.axis_o_tlast ({      main_out_axis_tlast,
                     main_checksum_axis_tlast}),
	.axis_o_tdata ({      main_out_axis_tdata,
                     main_checksum_axis_tdata})
);


axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(2)
) checksum_joiner (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready({main_checksum_axis_tready, ip_checksum_axis_tready}),
	.axis_i_tvalid({main_checksum_axis_tvalid, ip_checksum_axis_tvalid}),
	.axis_i_tlast ({main_checksum_axis_tlast,  ip_checksum_axis_tlast}),
	.axis_i_tdata ({main_checksum_axis_tdata,  ip_checksum_axis_tdata}),

	.axis_o_tready(checksum_in_axis_tready),
	.axis_o_tvalid(checksum_in_axis_tvalid),
	.axis_o_tlast (checksum_in_axis_tlast),
	.axis_o_tdata (checksum_in_axis_tdata)
);

udp_checksum
#(
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) checksum (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(checksum_in_axis_tready),
	.axis_i_tvalid(checksum_in_axis_tvalid),
	.axis_i_tlast (checksum_in_axis_tlast),
	.axis_i_tdata (checksum_in_axis_tdata),

	.axis_o_tready(checksum_out_axis_tready),
	.axis_o_tvalid(checksum_out_axis_tvalid),
	.axis_o_tlast (checksum_out_axis_tlast),
	.axis_o_tdata (checksum_out_axis_tdata)
);

axis_fifo
#(
	.AXIS_BYTES(1)
) checksum_fifo (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(checksum_out_axis_tready),
	.axis_i_tvalid(checksum_out_axis_tvalid),
	.axis_i_tlast (checksum_out_axis_tlast),
	.axis_i_tdata (checksum_out_axis_tdata),

	.axis_o_tready(checksum_fifoed_axis_tready),
	.axis_o_tvalid(checksum_fifoed_axis_tvalid),
	.axis_o_tlast (checksum_fifoed_axis_tlast),
	.axis_o_tdata (checksum_fifoed_axis_tdata)
);

vector_to_axis
#(
	.VEC_BYTES(2*IP_ADDR_OCTETS),
	.AXIS_BYTES(1),
	.MSB_FIRST(1)
) ip_vec (
	.clk(clk),
	.sresetn(sresetn),

	.vec({src_ip, dest_ip}),

	.axis_tready(axis_ip_tready),
	.axis_tvalid(axis_ip_tvalid),
	.axis_tlast (axis_ip_tlast),
	.axis_tdata (axis_ip_tdata)
);

axis_round_robin
#(
	.AXIS_BYTES(1),
	.NUM_SLAVE_STREAMS(2)
) ip_round_robin (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(axis_ip_tready),
	.axis_i_tvalid(axis_ip_tvalid),
	.axis_i_tlast (axis_ip_tlast),
	.axis_i_tdata (axis_ip_tdata),

	.axis_o_tready({      ip_out_axis_tready,
	                 ip_checksum_axis_tready}),

	.axis_o_tvalid({      ip_out_axis_tvalid,
	                 ip_checksum_axis_tvalid}),

	.axis_o_tlast ({      ip_out_axis_tlast,
	                 ip_checksum_axis_tlast}),

	.axis_o_tdata ({      ip_out_axis_tdata,
	                 ip_checksum_axis_tdata})
);

axis_joiner
#(
	.AXIS_BYTES(1),
	.NUM_STREAMS(3)
) output_joiner (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready({          ip_out_axis_tready,
	                 checksum_fifoed_axis_tready,
	                        main_out_axis_tready}),

	.axis_i_tvalid({          ip_out_axis_tvalid,
	                 checksum_fifoed_axis_tvalid,
	                        main_out_axis_tvalid}),

	.axis_i_tlast ({          ip_out_axis_tlast,
	                 checksum_fifoed_axis_tlast,
	                        main_out_axis_tlast}),

	.axis_i_tdata ({          ip_out_axis_tdata,
	                 checksum_fifoed_axis_tdata,
	                        main_out_axis_tdata}),

	.axis_o_tready(axis_o_tready),
	.axis_o_tvalid(axis_o_tvalid),
	.axis_o_tlast (axis_o_tlast),
	.axis_o_tdata (axis_o_tdata)
);

endmodule
