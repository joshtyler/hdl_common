//UART Transmitter
//1 stop bit, no parity bits

module uart_tx
#(
	parameter integer CLK_FREQ = 100e6,
	parameter integer BAUD_RATE = 9600,
	parameter integer DATA_BITS = 8
) (
	input logic clk,
	input logic sresetn,

	output logic serial_data,

	output logic s_axis_tready,
	input logic s_axis_tvalid,
	input logic[DATA_BITS-1:0] s_axis_tdata
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
logic [$clog2(CLKS_PER_BIT)-1:0] baud_ctr;
logic [(DATA_BITS+2)-1:0] data_reg;
logic [$clog2(DATA_BITS+2)-1:0] data_ctr; // Data bits+2 because we also hold the start and stop bit

logic[0:0] state;
localparam CAPTURE = 1'b0; // Wait for start of transmission
localparam SEND    = 1'b1; // Capture values of all bits except start bit

always_comb
begin
	s_axis_tready = (state == CAPTURE);
end

logic serial_data_reg;

always_comb
begin
	// Default to high when in reset (even if clock is not running)
	serial_data = (!sresetn) || serial_data_reg;
end

always @(posedge clk)
begin
	if(!sresetn) begin
		state <= CAPTURE;
		serial_data_reg <= 1;
	end else begin

			baud_ctr <= baud_ctr + 1;
			if(baud_ctr == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0]-1)
			begin
				data_ctr <= data_ctr + 1;
				baud_ctr <= 0;
			end

		case(state)
			CAPTURE : begin
				baud_ctr <= 0; // Number of clock cycles per bit
				data_ctr <= 0; // Current data bit
				data_reg <= {1'b1, s_axis_tdata, 1'b0}; //Stop bit, data, start bit

				if(s_axis_tready && s_axis_tvalid)
				begin
					state <= SEND;
				end
			end
			SEND : begin
				serial_data_reg <= data_reg[data_ctr];
				if((data_ctr == DATA_BITS[$clog2(DATA_BITS+2)-1:0]+1) && (baud_ctr == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0]-1)) // End of stop bit
				begin
					state <= CAPTURE;
				end
			end
		endcase
	end
end
endmodule
