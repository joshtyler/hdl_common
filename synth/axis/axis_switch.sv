// Send one slave to many masters based upon tdest
// Support for multiple slaves may be added later

module axis_switch
#(
	parameter AXIS_BYTES = 1,
	parameter AXIS_TDEST_BITS = 4;
	parameter NUM_SLAVE_STREAMS = 1
) (
	input clk,
	input sresetn,

	// Input
	output                      axis_i_tready,
	input                       axis_i_tvalid,
	input                       axis_i_tlast,
	input [AXIS_TDEST_BITS-1:0] axis_i_tdest,
	input [(AXIS_BYTES*8)-1:0]  axis_i_tdata,

	// Output
	input  [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tready,
	output [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tvalid,
	output [NUM_SLAVE_STREAMS-1 : 0]              axis_o_tlast,
	output [NUM_SLAVE_STREAMS*(AXIS_BYTES*8)-1:0] axis_o_tdata
);

genvar i;
for(i=0; i<NUM_SLAVE_STREAMS; i++)
begin
	axis_o_tlast[i] = axis_i_tlast;
	axis_o_tdata[(AXIS_BYTES*8)-1 -: 8] = axis_i_tdata;

	if(axis_i_tdest = i)
	begin
		axis_o_tvalid[i] = axis_i_tvalid;
		axis_i_tready = axis_o_tready[i];
	end else begin
		axis_o_tvalid[i] = 0;
	end;
end

endmodule
