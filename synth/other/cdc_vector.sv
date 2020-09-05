// Carry a vector across clock domains
// No flow control on output domain

module cdc_vector
#(
	parameter integer SYNC_STAGES = 2,
	parameter integer WIDTH = 2
) (
	input logic iclk,
	input logic oclk,
	// AXI stream compliant control interface for i
	output logic i_tready,
	input  logic i_tvalid,
	input  logic [WIDTH-1:0] i,
	// Strobe to show when o is updated
	// (But o is always valid)
	output logic o_strb,
	output logic [WIDTH-1:0] o
);

logic ack_iclk;

logic i_tready_sig = 0;
assign i_tready = i_tready_sig;
always @(posedge iclk)
begin
	if(i_tready_sig)
	begin
		if(i_tvalid)
		begin
			i_tready_sig <= 0;
		end
	end else begin
		if(ack_iclk)
		begin
			i_tready_sig <= 1;
		end
	end
end

logic [WIDTH-1:0] i_reg;
logic en_iclk = 0;
always_ff @(posedge iclk)
begin
	if(i_tready && i_tvalid)
	begin
		en_iclk <= !en_iclk;
		i_reg <= i;
	end
end

logic en_oclk, ack_oclk;
cdc_pulse #(.SYNC_STAGES(SYNC_STAGES)) ackogen (.oclk(oclk), .i(en_iclk), .opulse(en_oclk), .odata(ack_oclk));

logic o_strb_sig = 0;
assign o_strb = o_strb_sig;
always_ff @(posedge oclk)
begin
	o_strb_sig <= 0;
	if (en_oclk)
	begin
		o <= i_reg;
		o_strb_sig <= 1;
	end
end

cdc_pulse #(.SYNC_STAGES(SYNC_STAGES)) ackigen (.oclk(iclk), .i(ack_oclk), .opulse(ack_iclk));

endmodule
