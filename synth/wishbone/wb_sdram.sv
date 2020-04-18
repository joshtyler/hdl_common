// Simple SDRAM controller
// Current features/limitaions
	// Single bank open at once
	// No burst support
	// Never precharge after write
// The controller is designed in an extensible manner to support overcoming these limitations in the future

// Theory of operation:
/*

 ______________        ______________
|              |      | Operation    |
| WB Interface | ---> | Encoder      |
|              |      |              |
 --------------        --------------
                             ^
                             |
                       ______________
                      |              |
                      | Refresh logic|
                      |              |
                       --------------



*/

module wb_sdram
#(
	parameter ROW_ADDR_BITS = 12,
	parameter COL_ADDR_BITS = 9,
	parameter BANK_SEL_BITS = 2,
	parameter DATA_BYTES = 2,
	parameter CLK_RATE      = 50_000_000,
	parameter T_RC_ps       = 60_000,
	parameter T_RP_ps       = 15_000,
	parameter T_CL          = 3,
	parameter T_RSC         = 2,
	parameter REFRSH_PERIOD_ms = 64,
	parameter T_RAS_min_ps  = 42_000,
	// It is advisable to be slightly cautious with T_RAS_max
	// This is because the state machine might take one or two exta cycles to honor it
	// Not currently a concern since we currently break out long before it is a problem for refreshes
	parameter T_RAS_max_ps  = 99800_000,
	parameter T_RCD_ps      = 15_000,
	parameter T_WR          = 2,
	parameter WB_ADDR_BITS = BANK_SEL_BITS+ROW_ADDR_BITS+COL_ADDR_BITS // Should be localparm, but iverlog doesn't like it
) (
	input logic clk,
	input logic sresetn,

	//Wishbone interface
	input  logic [WB_ADDR_BITS-1:0] s_wb_addr,
	input  logic [DATA_BYTES*8-1:0] s_wb_dat_m2s,
	output logic [DATA_BYTES*8-1:0] s_wb_dat_s2m,
	input  logic                    s_wb_we,
	input  logic                    s_wb_stb,
	output logic                    s_wb_ack,
	output logic                    s_wb_stall,

	// SDRAM interface
	// N.B ram_dq is split into three ports
	// It is intended to have the following at the top level
	// inout logic [DATA_BYTES*8-1:0]  ram_dq,
	// ...
	// assign ram_dq_i = ram_dq;
	// assign ram_dq = ram_dq_oe? ram_dq_o : 'z;
	output logic [ROW_ADDR_BITS-1:0] ram_a,
	output logic [BANK_SEL_BITS-1:0] ram_bs,
	output logic [DATA_BYTES*8-1:0]  ram_dq_o,
	output logic                     ram_dq_oe,
	input  logic [DATA_BYTES*8-1:0]  ram_dq_i,
	output logic                     ram_cs_n,
	output logic                     ram_ras_n,
	output logic                     ram_cas_n,
	output logic                     ram_we_n,
	output logic [DATA_BYTES-1:0]    ram_dqm,
	output logic                     ram_cke
);

localparam FIFO_DEPTH = 128;
logic sdram_dat_to_user_valid;

logic addr_cmd_fifo_i_tready;
logic addr_cmd_fifo_i_tvalid;

logic cmd_ready;
logic cmd_valid;
logic [WB_ADDR_BITS-1:0] cmd_addr;
logic cmd_we;

// The reverse channel on wb is not flow controlled
assign s_wb_dat_s2m = ram_dq_i;
logic read_dq_valid;

// Ack all of the writes as soon as we receive them
logic r_dat_ack;
always @(posedge clk)
begin
	r_dat_ack <= addr_cmd_fifo_i_tvalid && addr_cmd_fifo_i_tready && s_wb_we;
end

// The OR works because we know that the wishbone master must clear outstanding reads before turning around the bus
assign s_wb_ack = read_dq_valid || r_dat_ack;

assign addr_cmd_fifo_i_tvalid = s_wb_stb;
assign s_wb_stall = !addr_cmd_fifo_i_tready;

axis_fifo
#(
	.AXIS_BYTES(1), // Not used
	.AXIS_USER_BITS(WB_ADDR_BITS+1),
	.DEPTH(FIFO_DEPTH)
) addr_cmd_fifo (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(addr_cmd_fifo_i_tready),
	.axis_i_tvalid(addr_cmd_fifo_i_tvalid),
	.axis_i_tlast(1'b0),
	.axis_i_tdata({8{1'b1}}),
	.axis_i_tuser({s_wb_we, s_wb_addr}),

	.axis_o_tready(cmd_ready),
	.axis_o_tvalid(cmd_valid),
	.axis_o_tlast(),
	.axis_o_tdata(),
	.axis_o_tuser({cmd_we, cmd_addr})
);

logic wr_dat_fifo_i_tvalid;
assign wr_dat_fifo_i_tvalid = addr_cmd_fifo_i_tvalid && s_wb_we;
axis_fifo
#(
	.AXIS_BYTES(DATA_BYTES),
	.DEPTH(FIFO_DEPTH)
) wr_dat_fifo (
	.clk(clk),
	.sresetn(sresetn),

	.axis_i_tready(), // Because this is at least as full, if not more full that the meta fifo, we know when this is ready from the meta fifo
	.axis_i_tvalid(wr_dat_fifo_i_tvalid),
	.axis_i_tlast(1'b0),
	.axis_i_tdata(s_wb_dat_m2s),

	.axis_o_tready(cmd_ready && cmd_we),
	.axis_o_tvalid(), // We know from the meta fifo when this will be valid
	.axis_o_tlast(),
	.axis_o_tdata(ram_dq_o)
);
assign ram_dq_oe = cmd_ready && cmd_valid && cmd_we;

wb_sdram_controller
#(
	.ROW_ADDR_BITS (ROW_ADDR_BITS),
	.COL_ADDR_BITS (COL_ADDR_BITS),
	.BANK_SEL_BITS (BANK_SEL_BITS),
	.DATA_BYTES    (DATA_BYTES   ),
	.CLK_RATE      (CLK_RATE     ),
	.T_RC_ps       (T_RC_ps      ),
	.T_RP_ps       (T_RP_ps      ),
	.T_CL          (T_CL         ),
	.T_RSC         (T_RSC        ),
	.REFRSH_PERIOD_ms (REFRSH_PERIOD_ms),
	.T_RAS_min_ps  (T_RAS_min_ps ),
	.T_RAS_max_ps  (T_RAS_max_ps ),
	.T_RCD_ps      (T_RCD_ps     ),
	.T_WR          (T_WR         )
) contoller_inst (
	.clk(clk),
	.sresetn(sresetn),

	.cmd_i_ready(cmd_ready),
	.cmd_i_valid(cmd_valid),
	.cmd_i_addr (cmd_addr),
	.cmd_i_we   (cmd_we),

	.read_dq_valid(read_dq_valid),

	.ram_a     (ram_a),
	.ram_bs    (ram_bs),
	.ram_cs_n  (ram_cs_n),
	.ram_ras_n (ram_ras_n),
	.ram_cas_n (ram_cas_n),
	.ram_we_n  (ram_we_n),
	.ram_dqm   (ram_dqm),
	.ram_cke   (ram_cke)
);


endmodule
