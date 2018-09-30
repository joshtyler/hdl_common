// Enforce a gap between packets

module axis_spacer
#(
	parameter AXIS_BYTES = 1,
	parameter GAP_CYCLES = 1
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
localparam integer CTR_WIDTH = GAP_CYCLES == 1? 1 : $clog2(GAP_CYCLES);
/* verilator lint_off WIDTH */
localparam CTR_MAX = GAP_CYCLES-1;
/* verilator lint_on WIDTH */
logic [CTR_WIDTH-1:0] ctr;

logic [0:0] state;
localparam PASS = 1'b0;
localparam HALT = 1'b1;

assign axis_o_tdata = axis_i_tdata;
assign axis_o_tlast = axis_i_tlast;

assign axis_o_tvalid = (state == PASS)? axis_i_tvalid : 0;
assign axis_i_tready = (state == PASS)? axis_o_tready : 0;

always @(posedge clk)
	if (sresetn == 0)
	begin
		state <= PASS;
	end else begin
		case(state)
			PASS: begin
				if (axis_i_tready && axis_i_tvalid && axis_i_tlast) begin
					ctr <= 0;
					state <= HALT;
				end
			end
			HALT: begin
				if (ctr == CTR_MAX) begin
					state <= PASS;
				end
				ctr <= ctr + 1;
			end
		endcase
	end

endmodule
