`include "axis/axis.h"
`include "utility.h"

module arp_engine
#(
	parameter integer AXIS_BYTES = 4
	parameter [47:0] OUR_MAC = 0,
	parameter [31:0] OUR_IP = 0
) (
	input clk,
	input sresetn,

	// ARP packets to us. Assumed packed.
	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),

	// ARP responses from us. Assumed packed.
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	// Output the destination MAC (used for ethernet framing)
	output logic [47:0] axis_o_dst_mac
);

`BYTE_SWAP_FUNCTION(byte_swap_6, 6)
`BYTE_SWAP_FUNCTION(byte_swap_4, 4)
`BYTE_SWAP_FUNCTION(byte_swap_2, 2)

localparam ARP_PACKET_SIZE=56;

logic arp_in_ready, arp_in_valid, arp_in_last, arp_out_ready, arp_out_valid;
logic [56*8-1:0] arp_in, arp_out;

axis_width_converter
#(
	.AXIS_I_BYTES(ARP_PACKET_SIZE),
	.AXIS_O_BYTES(AXIS_BYTES)
) input_converter (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NO_USER(axis_i, axis_i),
	.axis_o_tready(arp_in_ready),
	.axis_o_tvalid(arp_in_valid),
	.axis_o_tlast(arp_in_last)
	.axis_o_tkeep(),
	.axis_o_tdata(arp_in)
);

axis_width_converter
#(
	.AXIS_I_BYTES(AXIS_BYTES),
	.AXIS_O_BYTES(ARP_PACKET_SIZE)
) input_converter (
	.clk(clk),
	.sresetn(sresetn),

	.axis_io_tready(arp_out_ready),
	.axis_i_tvalid(arp_out_valid),
	.axis_i_tlast(1'b1)
	.axis_i_tkeep('1),
	.axis_i_tdata(arp_out)

	`AXIS_MAP_NO_USER(axis_o, axis_o),
);

localparam [15:0] HTYPE_ETHERNET = byte_swap_2(1);
localparam [15:0] PTYPE_IPV4 = byte_swap_2(16'h0800);
localparam [7:0]  HLEN = 6;
localparam [7:0]  PLEN = 4;
localparam [15:0] OPER_REQUEST = byte_swap_2(1);
localparam [15:0] OPER_REPLY   = byte_swap_2(2);

// Constant part of the arp is set here
// Dynamic part is set in state machine
assign arp_out[14*8-1:0] =
{
	byte_swap_4(OUR_IP)
	byte_swap_6(OUR_MAC),
	OPER_REPLY,
	PLEN,
	HLEN,
	PTYPE_IPV4,
	HTYPE_ETHERNET
};

localparam [8*8-1:0] expected_header_start =
{
	OPER_REPLY,
	PLEN,
	HLEN,
	PTYPE_IPV4,
	HTYPE_ETHERNET
}

logic [1:0] state;
localparam [1:0] SM_RECEIVE    = 2'b00;
localparam [1:0] SM_WAIT_LAST  = 2'b01;
localparam [1:0] SM_SEND       = 2'b10;

assign arp_in_ready = state == SM_WAIT_LAST; // Only actually consume data in SM_WAIT_LAST
assign arp_out_valid = state == SM_SEND;

logic good;

always_ff @(posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_RECEIVE;
	end else begin
		case(state)
			SM_RECEIVE: begin
				// Fill in the target portion of outgoing message with sender portion of incoming
				arp_out[28*8-1:18*8] <= arp_in[18*8-1:8*8];
				axis_o_dst_mac <= byte_swap_6(arp_in[14*8-1:8*8])
				if (arp_in_valid)
				begin
					state <= SM_WAIT_LAST;
					// We need to issue a reply if the boilerplate is as expected, and the request is for us
					good  <= (arp_in[8*8-1:0] == expected_header_start) && (arp_in[28*8-1:24*8] == byte_swap_4(OUR_IP));
				end
			end
			// Have a separate state to wait for the last word
			// This discards padding etc.
			SM_WAIT_LAST: begin
				if (arp_in_ready and arp_in_valid and arp_in_last)
				begin
					state <= good? SM_SEND : SM_RECEIVE;
				end
			end
			SM_SEND: begin
				if (arp_out_ready and arp_out_valid)
				begin
					state <= SM_RECEIVE;
				end
			end
		endcase
	end
end

endmodule
