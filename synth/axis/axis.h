`ifndef AXIS_H
`define AXIS_H


// Macros which expand to port declarations:
	// Slave / master
	// Single stream or packed

`define S_AXIS_PORT_NO_USER(PREFIX, AXIS_BYTES) \
output logic                     ``PREFIX``_tready, \
input logic                      ``PREFIX``_tvalid, \
input logic                      ``PREFIX``_tlast, \
input logic [(AXIS_BYTES*8)-1:0] ``PREFIX``_tdata

`define S_AXIS_PORT(PREFIX, AXIS_BYTES, AXIS_USER_BITS) \
`S_AXIS_PORT_NO_USER(PREFIX, AXIS_BYTES), \
input logic [AXIS_USER_BITS-1:0] ``PREFIX``_tuser

`define M_AXIS_PORT_NO_USER(PREFIX, AXIS_BYTES) \
input logic                       ``PREFIX``_tready, \
output logic                      ``PREFIX``_tvalid, \
output logic                      ``PREFIX``_tlast, \
output logic [(AXIS_BYTES*8)-1:0] ``PREFIX``_tdata

`define M_AXIS_PORT(PREFIX, AXIS_BYTES, AXIS_USER_BITS) \
`M_AXIS_PORT_NO_USER(PREFIX, AXIS_BYTES), \
output logic [AXIS_USER_BITS-1:0] ``PREFIX``_tuser

`define S_AXIS_MULTI_PORT(PREFIX, NUM_STREAMS, AXIS_BYTES, AXIS_USER_BITS) \
output logic  [NUM_STREAMS-1 : 0]            ``PREFIX``_tready, \
input logic [NUM_STREAMS-1 : 0]              ``PREFIX``_tvalid, \
input logic [NUM_STREAMS-1 : 0]              ``PREFIX``_tlast,\
input logic [NUM_STREAMS*(AXIS_BYTES*8)-1:0] ``PREFIX``_tdata, \
input logic [NUM_STREAMS*AXIS_USER_BITS-1:0] ``PREFIX``_tuser

`define M_AXIS_MULTI_PORT(PREFIX, NUM_STREAMS, AXIS_BYTES, AXIS_USER_BITS) \
input logic  [NUM_STREAMS-1 : 0]              ``PREFIX``_tready, \
output logic [NUM_STREAMS-1 : 0]              ``PREFIX``_tvalid, \
output logic [NUM_STREAMS-1 : 0]              ``PREFIX``_tlast, \
output logic [NUM_STREAMS*(AXIS_BYTES*8)-1:0] ``PREFIX``_tdata, \
output logic [NUM_STREAMS*AXIS_USER_BITS-1:0] ``PREFIX``_tuser

// Macros to declare an AXI stream instance

`define AXIS_INST_NO_USER(PREFIX, AXIS_BYTES) \
logic ``PREFIX``_tready; \
logic ``PREFIX``_tvalid; \
logic ``PREFIX``_tlast; \
logic [(AXIS_BYTES*8)-1:0] ``PREFIX``_tdata

`define AXIS_INST(PREFIX, AXIS_BYTES, AXIS_USER_BITS) \
`AXIS_INST_NO_USER(PREFIX, AXIS_BYTES); \
logic [AXIS_USER_BITS-1:0] ``PREFIX``_tuser


// Macros which expand to port maps:
	// Single stream or packed
	// tuser/null tuser/ignore tuser
// N.B. the multi macros are hardcoded because SV does not support variadic
// We could use a trick like http://ionipti.blogspot.com/2012/08/systemverilog-variable-argument-display.html to emulate this

`define AXIS_MAP_NO_USER(MOD_PREFIX, LOCAL_PREFIX) \
.``MOD_PREFIX``_tready(``LOCAL_PREFIX``_tready), \
.``MOD_PREFIX``_tvalid(``LOCAL_PREFIX``_tvalid), \
.``MOD_PREFIX``_tlast (``LOCAL_PREFIX``_tlast), \
.``MOD_PREFIX``_tdata (``LOCAL_PREFIX``_tdata)

`define AXIS_MAP(MOD_PREFIX, LOCAL_PREFIX) \
`AXIS_MAP_NO_USER(MOD_PREFIX, LOCAL_PREFIX), \
.``MOD_PREFIX``_tuser (``LOCAL_PREFIX``_tuser)

`define AXIS_MAP_NULL_USER(MOD_PREFIX, LOCAL_PREFIX) \
`AXIS_MAP_NO_USER(MOD_PREFIX, LOCAL_PREFIX), \
.``MOD_PREFIX``_tuser (1'b1)

`define AXIS_MAP_IGNORE_USER(MOD_PREFIX, LOCAL_PREFIX) \
`AXIS_MAP_NO_USER(MOD_PREFIX, LOCAL_PREFIX), \
.``MOD_PREFIX``_tuser ()

`define AXIS_MAP_2_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2) \
.``MOD_PREFIX``_tready({``LOCAL_PREFIX_1``_tready, ``LOCAL_PREFIX_2``_tready}), \
.``MOD_PREFIX``_tvalid({``LOCAL_PREFIX_1``_tvalid, ``LOCAL_PREFIX_2``_tvalid}), \
.``MOD_PREFIX``_tlast ({``LOCAL_PREFIX_1``_tlast , ``LOCAL_PREFIX_2``_tlast }), \
.``MOD_PREFIX``_tdata ({``LOCAL_PREFIX_1``_tdata , ``LOCAL_PREFIX_2``_tdata })

`define AXIS_MAP_2_NULL_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2) \
`AXIS_MAP_2_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2), \
.``MOD_PREFIX``_tuser (2'b1)

`define AXIS_MAP_2_IGNORE_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2) \
`AXIS_MAP_2_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2), \
.``MOD_PREFIX``_tuser ()

`define AXIS_MAP_3_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3) \
.``MOD_PREFIX``_tready({``LOCAL_PREFIX_1``_tready, ``LOCAL_PREFIX_2``_tready, ``LOCAL_PREFIX_3``_tready}), \
.``MOD_PREFIX``_tvalid({``LOCAL_PREFIX_1``_tvalid, ``LOCAL_PREFIX_2``_tvalid, ``LOCAL_PREFIX_3``_tvalid}), \
.``MOD_PREFIX``_tlast ({``LOCAL_PREFIX_1``_tlast , ``LOCAL_PREFIX_2``_tlast , ``LOCAL_PREFIX_3``_tlast }), \
.``MOD_PREFIX``_tdata ({``LOCAL_PREFIX_1``_tdata , ``LOCAL_PREFIX_2``_tdata , ``LOCAL_PREFIX_3``_tdata })

`define AXIS_MAP_3_NULL_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3) \
`AXIS_MAP_3_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3), \
.``MOD_PREFIX``_tuser (3'b1)

`define AXIS_MAP_4_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3, LOCAL_PREFIX_4) \
.``MOD_PREFIX``_tready({``LOCAL_PREFIX_1``_tready, ``LOCAL_PREFIX_2``_tready, ``LOCAL_PREFIX_3``_tready, ``LOCAL_PREFIX_4``_tready}), \
.``MOD_PREFIX``_tvalid({``LOCAL_PREFIX_1``_tvalid, ``LOCAL_PREFIX_2``_tvalid, ``LOCAL_PREFIX_3``_tvalid, ``LOCAL_PREFIX_4``_tvalid}), \
.``MOD_PREFIX``_tlast ({``LOCAL_PREFIX_1``_tlast , ``LOCAL_PREFIX_2``_tlast , ``LOCAL_PREFIX_3``_tlast , ``LOCAL_PREFIX_4``_tlast }), \
.``MOD_PREFIX``_tdata ({``LOCAL_PREFIX_1``_tdata , ``LOCAL_PREFIX_2``_tdata , ``LOCAL_PREFIX_3``_tdata , ``LOCAL_PREFIX_4``_tdata })

`define AXIS_MAP_4_NULL_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3, LOCAL_PREFIX_4) \
`AXIS_MAP_4_NO_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3, LOCAL_PREFIX_4), \
.``MOD_PREFIX``_tuser (4'b1)

`define AXIS_MAP_4_IGNORE_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3, LOCAL_PREFIX_4) \
`AXIS_MAP_4_IGNORE_USER(MOD_PREFIX, LOCAL_PREFIX_1, LOCAL_PREFIX_2, LOCAL_PREFIX_3, LOCAL_PREFIX_4), \
.``MOD_PREFIX``_tuser ()

`endif
