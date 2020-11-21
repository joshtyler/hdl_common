`include "axis/axis.h"
`include "utility.h"

module tcp_deframer
#(
	// Just support four bytes wide. This makes deframing much easier
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),
	output logic [15:0] axis_o_length_bytes, // From IP header

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	output logic [15:0] axis_o_length_bytes,
	output logic [15:0] axis_o_src_port,
	output logic [15:0] axis_o_dst_port,
	output logic [31:0] axis_o_seq_num,
	output logic [31:0] axis_o_ack_num,
	output logic        axis_o_ack,
	output logic        axis_o_rst,
	output logic        axis_o_syn,
	output logic        axis_o_fin,
	output logic [15:0] axis_o_window_size
);

`BYTE_SWAP_FUNCTION(byte_swap_4, 4)
`BYTE_SWAP_FUNCTION(byte_swap_2, 2)

logic [4:0] data_offset_ctr, data_offset;
always_ff @(posedge clk)
begin
	if ((!sresetn) or axis_i_tlast)
	begin
		data_offset_ctr <= 0;
		data_offset <= 3;
	end else begin
		if(axis_i_tready && axis_i_tvalid)
		begin
			// We don't have to worry about the special case of the first word becauase the counter is reset to the offset where we read the data_offset field
			// Allowing the counter to increment past unambigously indicates that we are in the data region
			// I.E. Mux then ctr > data_offset means that data will not be muxed if both are zero due to reset
			// To prevent overflow, we thus store the counter as zero indexed
			if (data_offset_ctr <= data_offset)
			begin
				data_offset_ctr <= data_offset_ctr + 1;
			end

			case(data_offset_ctr)
				0 :
				begin
					axis_o_src_port <= byte_swap_2(axis_i_tdata[15:0]);
					axis_o_dst_port <= byte_swap_2(axis_i_tdata[31:16]);
				end
				1 : axis_o_seq_num  <= byte_swap_4(axis_i_tdata);
				2 : axis_o_ack_num  <= byte_swap_4(axis_i_tdata);
				3 :
				begin
					data_offset <= axis_i_tdata[7:4];
					axis_o_ack <= axis_i_tdata[11];
					axis_o_rst <= axis_i_tdata[10];
					axis_o_syn <= axis_i_tdata[9];
					axis_o_fin <= axis_i_tdata[8];
					axis_o_window_size <= byte_swap_2(axis_i_tdata[31:15]);
				end
				// Ignore checksum/urgent pointer/options, and do nothing for the data segment
			endcase
		end
	end
end

// Always be ready when data is consumed by state machine
// Pass through to output when we are done with the header
logic header_finished;
assign header_finished = (data_offset_ctr > data_offset);
assign axis_i_tready  = header_finished? axis_o_tready : 1;
assign axis_o_tvalid = header_finished? axis_i_tvalid  : 0;
assign axis_o_tlast  = axis_i_tlast;
assign axis_o_tdata  = axis_i_tdata;

endmodule
