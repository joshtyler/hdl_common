module axis_register
#(
	parameter AXIS_BYTES = 1
) (
	input clk,
	input sresetn,

	// Input
	output                     axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input                       axis_o_tready,
	output                      axis_o_tvalid,
	output                      axis_o_tlast,
	output [(AXIS_BYTES*8)-1:0] axis_o_tdata
);
	// We are able to store data when the register is empty
	// Or we are also clocking data out
	assign axis_i_tready = (!axis_o_tvalid) || axis_o_tready;

	always @(posedge clk)
	begin
		if (sresetn == 0)
		begin
			axis_o_tvalid <= 0;
		end else begin
			if (axis_i_tready && axis_i_tvalid)
			begin
				// Fill the register if we are able
				axis_o_tvalid <= axis_i_tvalid;
				axis_o_tlast <= axis_i_tlast;
				axis_o_tdata <= axis_i_tdata;
			end else if (axis_o_tready)
			begin
				// If we are reading and not writing, invalidate the register
				axis_o_tvalid <= 0;
			end
		end
	end

endmodule
