module wb_axis_bridge
#(
	parameter BYTES = 1
) (
	input logic clk,
	input logic sresetn,

	// Wishbone
	input  logic wb_stb, // cyc assumed to be high
	input  logic wb_we,
	input  logic [(BYTES*8)-1:0] wb_data_i,
	output logic [(BYTES*8)-1:0] wb_data_o,
	output logic wb_ack,
	output logic wb_stall,

	// AXIS Input
	output logic                      axis_i_tready,
	input  logic                      axis_i_tvalid,
	input  logic [(BYTES*8)-1:0] axis_i_tdata,

	// AXIS Output
	input  logic                      axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic [(BYTES*8)-1:0] axis_o_tdata
);


logic wb_to_axis_tready;
logic wb_to_axis_tvalid;

logic axis_to_wb_tready;
logic axis_to_wb_tvalid;

// Ack logic
// We consider a transaction to be completed once it is part of the stream
always_ff @(posedge clk)
begin
	if(!sresetn)
	begin
		wb_ack <= 0;
	end else begin
		wb_ack <= wb_stb && !wb_stall;
	end
end

// Stall logic
always_comb
begin
	if(wb_stb)
	begin
		if(wb_we)
		begin
			wb_stall = !wb_to_axis_tready;
		end else begin
			wb_stall = !axis_to_wb_tvalid;
		end
	end else begin
		wb_stall = 0;
	end
end

always_comb
begin
	wb_to_axis_tvalid = wb_stb && wb_we;
	axis_to_wb_tready = wb_stb && !wb_we;
end

axis_register
#(
	.AXIS_BYTES(BYTES)
) wb_to_axis_reg (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(wb_to_axis_tready),
	.axis_i_tvalid(wb_to_axis_tvalid),
	.axis_i_tlast(0),
	.axis_i_tdata(wb_data_i),
	.axis_i_tuser(1'b0),

	.axis_o_tready(axis_o_tready),
	.axis_o_tvalid(axis_o_tvalid),
	.axis_o_tlast(),
	.axis_o_tdata(axis_o_tdata),
	.axis_o_tuser()
);


// We don't actually need the register on the axis_to_wb direction
// Ready is always asserted independantly of valid so it's axis compliant inherantly
// We need to register wb_data_o because ack is delayed by one clock also
assign axis_i_tready = axis_to_wb_tready;
assign axis_to_wb_tvalid = axis_i_tvalid;
always_ff @(posedge clk)
	wb_data_o <= axis_i_tdata;

endmodule
