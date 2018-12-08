module axis_padder
#(
	parameter AXIS_BYTES = 1,
	parameter MIN_LENGTH = 50,
	parameter [(AXIS_BYTES*8)-1:0] PAD_VALUE = 0
) (
	input clk,
	input sresetn,

	// Input
	output logic               axis_i_tready,
	input                      axis_i_tvalid,
	input                      axis_i_tlast,
	input [(AXIS_BYTES*8)-1:0] axis_i_tdata,

	// Output
	input                             axis_o_tready,
	output logic                      axis_o_tvalid,
	output logic                      axis_o_tlast,
	output logic [(AXIS_BYTES*8)-1:0] axis_o_tdata
);

	localparam integer CTR_WIDTH = $clog2(MIN_LENGTH);

	localparam [5:0] CTR_MAX = MIN_LENGTH-1;

	logic [CTR_WIDTH-1:0] ctr;

	logic [1:0] state;
	localparam [1:0] SM_PASSTHROUGH = 2'b00;
	localparam [1:0] SM_PAD = 2'b01;

	always @(posedge clk)
	begin
		if (sresetn == 0)
		begin
			ctr <= 0;
			state <= SM_PASSTHROUGH;
		end else begin
			// Handle counter
			// Increment on valid data
			// Halt on max value
			if (axis_o_tready && axis_o_tvalid)
			begin
				if(axis_o_tlast) begin
					ctr <= 0;
				end else begin
					if(ctr != CTR_MAX) begin
						ctr <= ctr + 1;
					end
				end
			end
			case(state)
				SM_PASSTHROUGH: if(axis_i_tready && axis_i_tvalid && axis_i_tlast && ctr != CTR_MAX) state <= SM_PAD;
				SM_PAD: if(axis_o_tready && axis_o_tvalid && axis_o_tlast && ctr == CTR_MAX) state <= SM_PASSTHROUGH;
				default: state <= SM_PASSTHROUGH; //Unused
			endcase
		end
	end


	assign axis_i_tready = (state == SM_PASSTHROUGH)? axis_o_tready : 0;
	assign axis_o_tvalid = (state == SM_PASSTHROUGH)? axis_i_tvalid : 1;
	assign axis_o_tdata  = (state == SM_PASSTHROUGH)? axis_i_tdata : PAD_VALUE;

	// tlast
	always @(*)
	begin
	case(state)
		SM_PASSTHROUGH: if(ctr == CTR_MAX) axis_o_tlast = axis_i_tlast; else axis_o_tlast = 0;
		SM_PAD: axis_o_tlast = (ctr == CTR_MAX);
		default: axis_o_tlast = 0;  //Unused
	endcase
	end

endmodule
