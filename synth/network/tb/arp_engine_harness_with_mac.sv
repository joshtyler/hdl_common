// Harness to interface the ARP block with an ethernet interface

`include "axis/axis.h"

module arp_engine_harness_with_mac
(
	input clk,

	input  logic       eth_rxclk,
	input  logic [7:0] eth_rxd,
	input  logic       eth_rxdv,
	input  logic       eth_rxer,
	output logic       eth_gtxclk,
	output logic [7:0] eth_txd,
	output logic       eth_txen,
	output logic       eth_txer,
	output logic       eth_phyrst_n
);

	localparam [15:0] ETHERTYPE_ARP = 16'h0806;
	localparam [47:0] OUR_MAC = 48'h070605040302;
	localparam [31:0] OUR_IP  = {8'd110, 8'd0, 8'd0, 8'd10};

	logic sresetn;
	reset_gen #(.POLARITY(0), .COUNT(127)) reset_gen (.clk(clk), .en('1), .sreset(sresetn));

	logic eth_sresetn;
	reset_gen #(.POLARITY(0), .COUNT(127)) eth_reset_gen (.clk(eth_rxclk), .en('1), .sreset(eth_sresetn));
	assign eth_gtxclk = eth_rxclk;
	assign eth_phyrst_n = 1;

	`AXIS_INST_NO_USER(axis_from_mac, 4);

	gmii_rx_mac_async
	#(
		.AXIS_BYTES(4)
	) rx_mac (
		.eth_clk(eth_rxclk),
		.eth_sresetn(eth_sresetn),

		.eth_rxd(eth_rxd),
		.eth_rxdv(eth_rxdv),
		.eth_rxer(eth_rxer),

		.axis_clk(clk),
		.axis_sresetn(sresetn),

		`AXIS_MAP_NO_USER(axis_o, axis_from_mac)
	);


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

		`AXIS_MAP_NO_USER(axis_i, axis_from_mac),
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

	`AXIS_INST_NO_USER(axis_to_mac, 4);
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

		`AXIS_MAP_NO_USER(axis_o, axis_to_mac)
	);


	`AXIS_INST_NO_USER(axis_to_mac_packetised, 4);

	axis_packet_fifo_async
	#(
		.AXIS_BYTES(4),
		.LOG2_DEPTH(8) // Plenty for an ARP(!)
	) packet_fifo (
		.i_clk(clk),
		.i_sresetn(sresetn),

		.o_clk(eth_rxclk),
		.o_sresetn(eth_sresetn),

		`AXIS_MAP_NULL_USER(axis_i, axis_to_mac),
		.axis_i_drop(0),
		`AXIS_MAP_IGNORE_USER(axis_o, axis_to_mac_packetised)
	);

	`AXIS_INST_NO_USER(axis_to_mac_packetised_reg, 4);

	axis_register
	#(
		.AXIS_BYTES(4)
	) packet_fifo_out_reg (
		.clk(eth_rxclk),
		.sresetn(eth_sresetn),

		`AXIS_MAP_NULL_USER(axis_i, axis_to_mac_packetised),
		`AXIS_MAP_IGNORE_USER(axis_o, axis_to_mac_packetised_reg)
	);

	gmii_tx_mac
	#(
		.AXIS_BYTES(4)
	) tx_mac (
		.clk(eth_rxclk),
		.sresetn(eth_sresetn),

		`AXIS_MAP_NO_USER(axis_i, axis_to_mac_packetised_reg),

		.eth_txd (eth_txd),
		.eth_txen(eth_txen),
		.eth_txer(eth_txer)
	);
endmodule
