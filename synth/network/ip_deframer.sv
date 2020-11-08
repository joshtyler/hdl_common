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

localparam integer BASE_HEADER_LEN = 20;
localparam integer BASE_HEADER_CTR_LEN = $clog2(BASE_HEADER_LEN);

axis_splitter
#(
	.AXIS_BYTES(AXIS_BYTES),
	.SPLIT_WORD_OFFSET(19) // IP header len without any options
) split_header (
	.clk(clk),
	.sresetn(sresetn),

	`S_AXIS_MAP_NULL_USER(axis_i, axis_framed),
	`AXIS_MAP_IGNORE_USER(axis_o1, axis_header),
	`AXIS_MAP_IGNORE_USER(axis_o2, axis_options_body)
);

axis_width_converter
#(
	.AXIS_I_BYTES(AXIS_BYTES),
	.AXIS_O_BYTES(4)
) split_header (
	.clk(clk),
	.sresetn(sresetn),

	`S_AXIS_MAP_NULL_USER(axis_i, axis_framed),
	`AXIS_MAP_IGNORE_USER(axis_o1, axis_header),
	`AXIS_MAP_IGNORE_USER(axis_o2, axis_options_body)
);


// IHL is 4 bits wide = up to 15 32 bit wide chunks
// 5 of these are for the base header
// Therefore up to 10*4 bytes
// $clog2(40) = 6
// Actually, let's just work in 32 bit chunks
logic [4:0] remaining_ihl;

logic new_header;
always_ff @(posedge clk)
begin
	if (!sresetn)
	begin
		new_header <= 1;
	end else begin
		if(axis_header_tready && axis_header_tvalid)
		begin
			if(axis_header_tlast)
			begin
				new_header <= 1;
			end else begin
				new_header <= 0;
				if(new_header)
				begin
					remaining_ihl <= axis_header_tdata[7:4] - 1;
					m_axis_payload_length <= {axis_header_tdata[23:16]  axis_header_tdata[31:24]} - (axis_header_tdata[7:4] * 4); // Payload length is total length - IHL converted to bytes
				end else begin
					remaining_ihl <= remaining_ihl - 1;
					case(remaining_ihl)
						1 : m_axis_protocol <= axis_header_tdata[15:8];
						2 : m_axis_src_ip <= axis_header_tdata;
						3 : m_axis_dst_ip <= axis_header_tdata;
					endcase

				end
			end
		end
	end
end

// Maybe instead better to width convert to 32 on way in and out
// But will need to implement tkeep




endmodule
