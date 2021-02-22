// Harness to interface the ARP block with an ethernet interface

`include "axis/axis.h"

module arp_engine_harness
(
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, 4),
	`M_AXIS_PORT_NO_USER(axis_o, 4)
);

	localparam [15:0] ETHERTYPE_ARP = 16'h0806;
	localparam [47:0] OUR_MAC = 48'h070605040302;
	localparam [31:0] OUR_IP  = {8'd110, 8'd0, 8'd0, 8'd10};

	`AXIS_INST_NO_USER(axis_from_mac_no_eth_unpacked, 4);
	logic [47:0] axis_from_mac_no_eth_unpacked_dst_mac;
	logic [47:0] axis_from_mac_no_eth_unpacked_src_mac;
	logic [15:0] axis_from_mac_no_eth_unpacked_ethertype;

	eth_deframer
	#(
		.AXIS_BYTES(4),
		.REQUIRE_PACKED_OUTPUT(1)
	) eth_deframer (
		.clk(clk),
		.sresetn(sresetn),

		`AXIS_MAP_NO_USER(axis_i, axis_i),
		`AXIS_MAP_NO_USER(axis_o, axis_from_mac_no_eth_unpacked),
		.axis_o_dst_mac(axis_from_mac_no_eth_unpacked_dst_mac),
		.axis_o_src_mac(axis_from_mac_no_eth_unpacked_src_mac),
		.axis_o_ethertype(axis_from_mac_no_eth_unpacked_ethertype)
	);

	logic packet_is_ok;

	// Okay if multicast, or unicast and  intended for us and an ARP packet
	assign packet_is_ok = ((axis_from_mac_no_eth_unpacked_dst_mac[0] == 1) || (axis_from_mac_no_eth_unpacked_dst_mac == OUR_MAC)) && (axis_from_mac_no_eth_unpacked_ethertype == ETHERTYPE_ARP);

	`AXIS_INST_NO_USER(axis_arp_tx, 4);
	logic [47:0] arp_dst_mac;
	arp_engine
	#(
		.AXIS_BYTES(4),
		.OUR_MAC(OUR_MAC),
		.OUR_IP(OUR_IP)
	) arp_engine (
		.clk(clk),
		.sresetn(sresetn),

		.axis_i_tready(axis_from_mac_no_eth_unpacked_tready),
		.axis_i_tvalid(axis_from_mac_no_eth_unpacked_tvalid && packet_is_ok),
		.axis_i_tlast(axis_from_mac_no_eth_unpacked_tlast),
		.axis_i_tkeep(axis_from_mac_no_eth_unpacked_tkeep),
		.axis_i_tdata(axis_from_mac_no_eth_unpacked_tdata),

		`AXIS_MAP_NO_USER(axis_o, axis_arp_tx),
		.axis_o_dst_mac(arp_dst_mac)
	);

	eth_framer
	#(
		.AXIS_BYTES(4),
		.REQUIRE_PACKED_OUTPUT(1)
	) eth_framer (
		.clk(clk),
		.sresetn(sresetn),

		`AXIS_MAP_NO_USER(axis_i, axis_arp_tx),
		.axis_i_dst_mac(arp_dst_mac),
		.axis_i_src_mac(OUR_MAC),
		.axis_i_ethertype(16'h0806),

		`AXIS_MAP_NO_USER(axis_o, axis_o)
	);
endmodule
