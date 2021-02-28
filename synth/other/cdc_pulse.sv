// Generate a pulse in the output clock domain on data change
// N.B. We must guarantee that the input domain must hold its value for >1.5 clock periods of the output clock to be sure we get the pulse

module cdc_pulse
#(
	parameter integer SYNC_STAGES = 2
) (
	input logic oclk,
	input logic i,
	output logic opulse,
	output logic odata = 0
);

logic synced;
cdc_sync #(.STAGES(SYNC_STAGES)) sync (.oclk(oclk), .i(i), .o(synced));

always_ff @(posedge oclk)
	odata <= synced;

always_comb
	opulse = synced ^ odata;

endmodule
