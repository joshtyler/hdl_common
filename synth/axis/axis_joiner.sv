// Join together multiple AXIS streams
// I.e. output a packet from stream 1, then stream 2 etc.

module axis_joiner
#(
	parameter AXIS_BYTES = 1,
	parameter NUM_STREAMS = 1
) (
	input clk,
	input sresetn,

	// Input
	output [NUM_STREAMS-1 : 0] axis_i_tready,
	input  [NUM_STREAMS-1 : 0] axis_i_tvalid,
	input  [NUM_STREAMS-1 : 0] axis_i_tlast,
	input  [NUM_STREAMS*(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input  axis_o_tready,
	output axis_o_tvalid,
	output axis_o_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o_tdata
);

localparam integer CTR_WIDTH = NUM_STREAMS == 1? 1 : $clog2(NUM_STREAMS);
/* verilator lint_off WIDTH */
localparam CTR_MAX = NUM_STREAMS-1;


reg [CTR_WIDTH-1:0] ctr;

always @(posedge clk)
begin
	if (sresetn == 0)
	begin
		ctr <= 0;
	end else begin
		if (axis_o_tready && axis_o_tvalid && axis_i_tlast[ctr])
		begin
			if (ctr == CTR_MAX)
			begin
				ctr <= 0;
			end else begin
				ctr <= ctr + 1;
			end
		end
	end
end

genvar i;
generate
	for(i=0; i< NUM_STREAMS; i++)
			assign axis_i_tready[i] = (i == ctr)? axis_o_tready : 0;
endgenerate

assign axis_o_tvalid = axis_i_tvalid[ctr];
assign axis_o_tlast = (ctr == CTR_MAX)? axis_i_tlast[ctr] : 0; //Only output tlast on last packet

assign axis_o_tdata = axis_i_tdata[(1+ctr)*(AXIS_BYTES*8)-1 -: AXIS_BYTES*8];
/* verilator lint_on WIDTH */

endmodule
