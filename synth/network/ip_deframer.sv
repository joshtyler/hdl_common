`include "axis.h"

module ip_deframer
#(
	// Just support four bytes wide. This makes deframing much easier
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_i, AXIS_BYTES),

	`M_AXIS_PORT_NO_USER(axis_o, AXIS_BYTES),
	output logic [15:0] axis_o_length,
	output logic [7:0]  axis_o_protocol,
	output logic [31:0] axis_o_src_ip,
	output logic [31:0] axis_o_dst_ip
);

logic [4:0] ihl_ctr, ihl;
always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		ihl_ctr <= 0;
	end else begin
		if(axis_i_tready && axis_i_tvalid)
		begin
			// We don't have to worry about the special case of the first word becauase the ihl_ctr is reset to zero on tlast
			// Therefore the condition will always be true
			// Allowing the IHL counter to increment past IHL can indicate unambigously that we are in the data region
			// I.E. Mux then ihl_ctr > ihl means that data will not be muxed if both are zero due to reset
			// To prevent overflow, we thus store ihl as zero indexed
			if (ihl_ctr <= ihl)
			begin
				ihl_ctr <= ihl_ctr + 1;
			end

			case(ihl_ctr)
				0 :
				begin
					// Stored zero indexed, see above
					ihl <= axis_i_tdata[7:4] - 1;
					// Payload length is total length - IHL converted to bytes
					axis_o_length <= {axis_i_tdata[23:16],  axis_i_tdata[31:24]} - (axis_i_tdata[7:4] * 4);
				end
				1 : axis_o_protocol <= axis_i_tdata[15:8];
				2 : axis_o_src_ip <= axis_i_tdata;
				3 : axis_o_dst_ip <= axis_i_tdata;
				// Ignore options, and do nothing for the data segment
			endcase

			// If this is the last beat, the next beat will be a new frame
			if(axis_i_tlast)
			begin
				ihl_ctr <= 0;
			end
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
assign axis_o_untrimmed_tdata  = axis_i_tdata;

axis_trimmer
#(
	.AXIS_BYTES(AXIS_BYTES),
	.LENGTH_BITS(16)
) trimmer (
	.clk(clk),
	.sresetn(sresetn),

	`AXIS_MAP_NULL_USER(axis_i, axis_o_untrimmed),
	.axis_i_len_bytes(axis_o_length),

	`AXIS_MAP_IGNORE_USER(axis_o, axis_o)
);

endmodule
