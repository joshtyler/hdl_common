`include "axis.h"

module ip_deframer
#(
	// Just support four bytes wide. This makes deframing much easier
	localparam integer AXIS_BYTES = 4
) (
	input clk,
	input sresetn,

	`S_AXIS_PORT_NO_USER(axis_framed, AXIS_BYTES),

	`M_AXIS_PORT_NO_USER(axis_payload, AXIS_BYTES),
	output logic [15:0] m_axis_payload_length,
	output logic [7:0]  m_axis_protocol,
	output logic [31:0] m_axis_src_ip,
	output logic [31:0] m_axis_dst_ip
);

`AXIS_INST_NO_USER(axis_header_native_width, AXIS_BYTES);
`AXIS_INST_NO_USER(axis_header, AXIS_BYTES);
`AXIS_INST_NO_USER(axis_options_body, AXIS_BYTES);

logic [4:0] ihl_ctr, ihl;
always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		ihl_ctr <= 0;
	end else begin
		if(axis_framed_tready && axis_framed_tvalid)
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

			case(remaining_ihl)
				0 :
				begin
					// Stored zero indexed, see above
					ihl <= axis_header_tdata[7:4] - 1;
					// Payload length is total length - IHL converted to bytes
					m_axis_payload_length <= {axis_header_tdata[23:16]  axis_header_tdata[31:24]} - (axis_header_tdata[7:4] * 4);
				end
				1 : m_axis_protocol <= axis_header_tdata[15:8];
				2 : m_axis_src_ip <= axis_header_tdata;
				3 : m_axis_dst_ip <= axis_header_tdata;
				// Ignore options, and do nothing for the data segment
			endcase
			
			// If this is the last beat, the next beat will be a new frame
			if(axis_framed_tlast)
			begin
				ihl_ctr <= 0;
			end
		end
	end
end

// Always be ready when data is consumed by state machine
// Pass through to output when we are done with the header
logic header_finished;
assign header_finished = (ihl_ctr > ihl);
assign axis_framed_tready  = header_finished? axis_payload_tready : 1;
assign axis_payload_tvalid = header_finished? axis_framed_tvalid  : 0;
assign axis_payload_tlast  = axis_framed_tlast;
assign axis_payload_tdata  = axis_framed_tdata;

endmodule
