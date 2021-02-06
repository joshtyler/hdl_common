`include "axis/axis.h"
`include "utility.h"

// Frame a TCP segment header
// Checksum is NOT filled
// This is because we would need to buffer all the data, so it is easier to inject later
module tcp_header_gen
#(
	// Just support four bytes wide. This makes deframing much easier
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	output logic       axis_i_tready,
	input logic        axis_i_tvalid
	input logic [15:0] axis_i_src_port,
	input logic [15:0] axis_i_dst_port,
	input logic [31:0] axis_i_seq_num,
	input logic [31:0] axis_i_ack_num,
	input logic        axis_i_ack,
	input logic        axis_i_rst,
	input logic        axis_i_syn,
	input logic        axis_i_fin,
	input logic [15:0] axis_i_window_size,

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES)
);

`BYTE_SWAP_FUNCTION(byte_swap_4, 4);
`BYTE_SWAP_FUNCTION(byte_swap_2, 2);

localparam [2:0] CTR_MAX = 3'b100; // Length, zero indexed
logic [2:0] ctr;

always_ff @(posedge clk)
begin
	if ((!sresetn) or (axis_o_tready && axis_o_tvalid && axis_o_tlast))
	begin
		ctr <= 0;
	end else begin
		if(axis_o_tready && axis_o_tvalid)
		begin
			ctr <= ctr + 1;
		end
	end
end

assign axis_i_tready = axis_o_tready && axis_o_tlast;
assign axis_o_tvalid = axis_i_tvalid;
assign axis_o_tlast = (ctr == CTR_MAX);
always_comb
begin
	axis_o_tdata <= 0;
	case(ctr)
		0 : axis_o_tdata = {byte_swap_2(axis_o_dst_port), byte_swap_2(axis_o_src_port)};
		1 : axis_o_tdata = byte_swap_4(axis_o_seq_num);
		2 : axis_o_tdata = byte_swap_4(axis_o_ack_num);
		3 : axis_o_tdata = {byte_swap_2(axis_o_window_size), 3'b000, axis_o_ack, 1'b0, axis_o_rst, axis_o_syn, axis_o_fin, data_offset, 4'b0000};
	endcase
end

endmodule
