// Cross clock packet FIFO
// Based on Chris cummings design (pointer passing version)

module axis_packet_fifo_async
#(
	parameter DSIZE = 8,
	parameter ASIZE = 4
) (
	output [DSIZE-1:0] rdata,
	output             wfull,
	output             rempty,
	input  [DSIZE-1:0] wdata,
	input              winc, wclk, wrst_n,
	input              rinc, rclk, rrst_n
);
	wire   [ASIZE-1:0] waddr, raddr;
	wire   [ASIZE:0]   wptr, rptr, wq2_rptr, rq2_wptr;

	sync_r2w sync_r2w  (.wq2_rptr(wq2_rptr), .rptr(rptr), .wclk(wclk), .wrst_n(wrst_n));
	sync_w2r sync_w2r  (.rq2_wptr(rq2_wptr), .wptr(wptr), .rclk(rclk), .rrst_n(rrst_n));

	fifomem #(DSIZE, ASIZE) fifomem
	(.rdata(rdata), .wdata(wdata),
	.waddr(waddr), .raddr(raddr),
	.wclken(winc), .wfull(wfull),
	.wclk(wclk));

	rptr_empty #(ASIZE) rptr_empty
	(.rempty(rempty),
	.raddr(raddr),
	.rptr(rptr),.rq2_wptr(rq2_wptr),
	.rinc(rinc), .rclk(rclk),
	.rrst_n(rrst_n));

	wptr_full  #(ASIZE) wptr_full
	(.wfull(wfull), .waddr(waddr),
	.wptr(wptr), .wq2_rptr(wq2_rptr),
	.winc(winc), .wclk(wclk),
	.wrst_n(wrst_n));
endmodule

module fifomem
#(
	parameter  DATASIZE = 8,
	parameter  ADDRSIZE = 4
) (
	output [DATASIZE-1:0] rdata,
	input  [DATASIZE-1:0] wdata,
	input  [ADDRSIZE-1:0] waddr, raddr,
	input                 wclken, wfull, wclk
);
	localparam DEPTH = 1<<ADDRSIZE;
	reg [DATASIZE-1:0] mem [0:DEPTH-1];
	assign rdata = mem[raddr];

	always @(posedge wclk)
		if (wclken && !wfull)
		mem[waddr] <= wdata;
endmodule

module sync_r2w
#(
	parameter ADDRSIZE = 4
) (
	output reg [ADDRSIZE:0] wq2_rptr,
	input      [ADDRSIZE:0] rptr,
	input                   wclk, wrst_n
);
	reg [ADDRSIZE:0] wq1_rptr;

	always @(posedge wclk or negedge wrst_n)
		if (!wrst_n)
			{wq2_rptr,wq1_rptr} <= 0;
		else
			{wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};
endmodule

module sync_w2r
#(
	parameter ADDRSIZE = 4
) (
	output reg [ADDRSIZE:0] rq2_wptr,
	input      [ADDRSIZE:0] wptr,
	input                   rclk, rrst_n
);
	reg [ADDRSIZE:0] rq1_wptr;
	always @(posedge rclk or negedge rrst_n)
		if (!rrst_n)
			{rq2_wptr,rq1_wptr} <= 0;
		else
			{rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
endmodule
