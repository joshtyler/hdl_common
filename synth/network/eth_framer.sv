// Copyright (C) 2021 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │
//  Open Hardware Description License, v. 1.0. If a copy                                                    │
//  of the OHDL was not distributed with this file, You                                                     │
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

// Format :
	// MAC Source
	// MAC Destination
	// Ethertype
	// Payload

// Does not include preamble, sfd, padding, crc,
// This is provided by the MAC

`include "axis/axis.h"
`include "utility.h"

module eth_framer
#(
	parameter integer AXIS_BYTES = 1,
	parameter REQUIRE_PACKED_OUTPUT = 1
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	input logic [(6*8)-1:0] axis_i_dst_mac,
	input logic [(6*8)-1:0] axis_i_src_mac,
	input logic [(2*8)-1:0] axis_i_ethertype,

	// Unpacked if AXIS_BYTES
	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES)
);

`BYTE_SWAP_FUNCTION(byte_swap_2, 2)

logic [0:0] state;
localparam [0:0] SM_HEADER = 1'b0;
localparam [0:0] SM_DATA = 1'b1;

logic header_ready, header_valid;
assign header_valid = axis_i_tvalid && (state == SM_HEADER);

`AXIS_INST_NO_USER(axis_i_gated, AXIS_BYTES);

assign axis_i_tready = (state == SM_DATA) && axis_i_gated_tready;
assign axis_i_gated_tvalid = (state == SM_DATA) && axis_i_tvalid;
assign axis_i_gated_tlast = axis_i_tlast;
assign axis_i_gated_tkeep = axis_i_tkeep;
assign axis_i_gated_tdata = axis_i_tdata;


always_ff @(posedge clk)
begin
	if(!sresetn)
	begin
		state <= SM_HEADER;
	end else begin
		case(state)
			SM_HEADER: begin
				if (header_ready && header_valid)
				begin
					state <= SM_DATA;
				end
			end
			SM_DATA: begin
				if (axis_i_tready && axis_i_tvalid && axis_i_tlast)
				begin
					state <= SM_HEADER;
				end
			end
		endcase
	end
end


`AXIS_INST_NO_USER(ethernet_header_native, AXIS_BYTES);

axis_width_converter
#(
	.AXIS_I_BYTES(6+6+2),
	.AXIS_O_BYTES(AXIS_BYTES)
) crc_unpacker (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(header_ready),
	.axis_i_tvalid(header_valid),
	.axis_i_tlast(1'b1),
	.axis_i_tkeep({6+6+2{1'b1}}),
	.axis_i_tdata({byte_swap_2(axis_i_ethertype), axis_i_src_mac, axis_i_dst_mac}),
	`AXIS_MAP_NO_USER(axis_o, ethernet_header_native)
);

`AXIS_INST_NO_USER(axis_unpacked_o, AXIS_BYTES);
axis_joiner
#(
	.AXIS_BYTES(AXIS_BYTES),
	.NUM_STREAMS(2)
) out_joiner (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_2_NULL_USER(axis_i, axis_i_gated, ethernet_header_native),
	`AXIS_MAP_IGNORE_USER(axis_o, axis_unpacked_o)
);

generate
	if(REQUIRE_PACKED_OUTPUT && ((14 % AXIS_BYTES) != 0))
	begin
		axis_packer
		#(
			.AXIS_BYTES(AXIS_BYTES)
		) packer (
			.clk(clk),
			.sresetn(sresetn),

			`AXIS_MAP_NO_USER(axis_i, axis_unpacked_o),
			`AXIS_MAP_NO_USER(axis_o, axis_o)
		);
	end else begin
		assign axis_unpacked_o_tready = axis_o_tready;
		assign axis_o_tvalid = axis_unpacked_o_tvalid;
		assign axis_o_tlast  = axis_unpacked_o_tlast;
		assign axis_o_tkeep  = axis_unpacked_o_tkeep;
		assign axis_o_tdata  = axis_unpacked_o_tdata;
	end
endgenerate

endmodule
