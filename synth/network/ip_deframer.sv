`include "axis/axis.h"
`include "utility.h"

module ip_deframer
#(
	// Just support four bytes wide. This makes deframing much easier
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	output logic [15:0] axis_o_length_bytes,
	output logic [7:0]  axis_o_protocol,
	output logic [31:0] axis_o_src_ip,
	output logic [31:0] axis_o_dst_ip
);

`BYTE_SWAP_FUNCTION(byte_swap_4, 4)
`BYTE_SWAP_FUNCTION(byte_swap_2, 2)

logic [3:0] ihl_ctr, ihl;
always_ff @(posedge clk)
begin
	if ((!sresetn) || axis_i_tlast)
	begin
		ihl_ctr <= 0;
	end else begin
		if(axis_i_tready && axis_i_tvalid)
		begin
		// We don't have to worry about the special case of the first word becauase the counter is reset to the offset where we read the data_offset field
		// Allowing the counter to increment past unambigously indicates that we are in the data region
		// I.E. Mux then ctr > data_offset means that data will not be muxed if both are zero due to reset
		// To prevent overflow, we thus store the counter as zero indexed
			if (ihl_ctr <= ihl)
			begin
				ihl_ctr <= ihl_ctr + 1;
			end

			case(ihl_ctr)
				0 :
				begin
					// Stored zero indexed, see above
					ihl <= axis_i_tdata[3:0] - 1;
					// Payload length is total length - IHL converted to bytes
					axis_o_length_bytes <= byte_swap_2(axis_i_tdata[31:16]) - (axis_i_tdata[3:0] * 4);
				end
				2 : axis_o_protocol <= axis_i_tdata[15:8];
				3 : axis_o_src_ip <= byte_swap_4(axis_i_tdata);
				4 : axis_o_dst_ip <= byte_swap_4(axis_i_tdata);
				// Ignore options, and do nothing for the data segment
			endcase
		end
	end
end

`AXIS_INST_NO_USER(axis_o_untrimmed, AXIS_BYTES);

// Always be ready when data is consumed by state machine
// Pass through to output when we are done with the header
logic header_finished;
assign header_finished = (ihl_ctr > ihl);
assign axis_i_tready  = header_finished? axis_o_untrimmed_tready : 1;
assign axis_o_untrimmed_tvalid = header_finished? axis_i_tvalid  : 0;
assign axis_o_untrimmed_tlast  = axis_i_tlast;
assign axis_o_untrimmed_tkeep  = axis_i_tkeep;
assign axis_o_untrimmed_tdata  = axis_i_tdata;

axis_trimmer
#(
	.AXIS_BYTES(AXIS_BYTES),
	.LENGTH_BITS(16)
) trimmer (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, axis_o_untrimmed),
	.axis_i_len_bytes(axis_o_length_bytes),

	`AXIS_MAP_IGNORE_USER(axis_o, axis_o)
);

endmodule
