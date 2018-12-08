// Send one slave to many masters based upon tdest
// Support for multiple slaves may be added later

module axis_switch
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_TDEST_BITS = 4,
	parameter NUM_SLAVE_STREAMS = 1
) (
	input clk,
	input sresetn,

	// Input
	output logic                       axis_i_tready,
	input  logic                       axis_i_tvalid,
	input  logic                       axis_i_tlast,
	input  logic [AXIS_TDEST_BITS-1:0] axis_i_tdest,
	input  logic [(AXIS_BYTES*8)-1:0]  axis_i_tdata,

	// Output
	input  logic [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tready,
	output logic [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tvalid,
	output logic [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tlast,
	output logic [NUM_SLAVE_STREAMS*(AXIS_BYTES*8)-1:0] axis_o_tdata
);

assign axis_i_tready = axis_o_tready[axis_i_tdest];

genvar i;
for(i=0; i < NUM_SLAVE_STREAMS; i=i+1)
begin
	assign axis_o_tlast[i] = axis_i_tlast;
	assign axis_o_tdata[((i+1)*AXIS_BYTES*8)-1 -: 8] = axis_i_tdata;

	always @(*)
		if(axis_i_tdest == i)
		begin
			axis_o_tvalid[i] = axis_i_tvalid;
		end else begin
			axis_o_tvalid[i] = 0;
		end
end

endmodule
