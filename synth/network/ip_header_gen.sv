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
	localparam integer IP_ADDR_OCTETS = 4;
	localparam integer PROTOCOL_OCTETS = 1;
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
	input        payload_length_axis_tready;
	input        payload_length_axis_tvalid;
	input        payload_length_axis_tlast;
	input [15:0] payload_length_axis_tdata;
)

// Octets 0:1, and 4:8 are constant in this implementation
// Therefore we can get away with hardcoding it
// See https://en.wikipedia.org/wiki/IPv4#Header to decode
localparam OCTETS_0_TO_1 = 16'h4500;
// Total length goes here
localparam OCTETS_4_TO_8 = 40'h00004000FF;
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

// Join inputs together
logic prot_axis_tready; // Dummy signal, ignored
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
	.axis_i_tvalid({                       '1',
	                    octets4to8_axis_tvalid,
	                 len_byte_wide_axis_tvalid,
	                    octets0to1_axis_tvalid}),
	.axis_i_tlast ({                     '1',
	                    octets4to8_axis_tlast,
	                 len_byte_wide_axis_tlast,
	                    octets0to1_axis_tlast}),
	.axis_i_tdata ({                     prot,
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
) bcaster (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(input_joined_axis_tready),
	.axis_i_tvalid(input_joined_axis_tvalid),
	.axis_i_tlast (input_joined_axis_tlast),
	.axis_i_tdata (input_joined_axis_tdata)

	.axis_o_tready({      main_out_axis_tready,
	                 main_checksum_axis_tready}),
	.axis_o_tvalid({      main_out_axis_tvalid,
	                 main_checksum_axis_tvalid}),
	.axis_o_tlast ({      main_out_axis_tlast,
                   main_checksum_axis_tlast}),
	.axis_o_tdata ({      main_out_axis_tdata,
                   main_checksum_axis_tdata})
);
