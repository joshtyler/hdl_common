`ifndef UTILITY_H
`define UTILITY_H

// Miscellaneous macros

// Macro for a generic byte swapping function
`define BYTE_SWAP_FUNCTION(NAME, N_BYTES) \
function logic[8*N_BYTES-1 :0] NAME; \
	input logic [8*N_BYTES-1 :0] data; \
	int i;\
	for(i=0 ; i<N_BYTES ; i=i+1) \
		NAME[8*(i+1)-1 -:8] = data[8*(N_BYTES-i)-1 -:8]; \
endfunction

// Check compile time conditions
`define STATIC_ASSERT(cond) \
generate \
if(!(cond)) \
begin \
	instantiate_module_that_doesnt_exist_to_trigger_error foo(); \
end \
endgenerate

`define INTEGER_DIV_CEIL(NUM, DENOM) (((NUM - 1)/DENOM) + 1)

// Not just called MAX to avoid clashes
`define GET_MAX(X, Y) (((X)>(Y)? (X) : (Y))

`endif
