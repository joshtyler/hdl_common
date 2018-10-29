#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vaxis_fifo.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

std::vector<std::vector<vluint8_t>> testFifo(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_fifo> uut;

	ClockGen clk(uut.getTime(), 1e-9, 100e6);
	AXISSink<vluint8_t> outAxis(clk, uut.uut->sresetn, uut.uut->axis_o_tready,
		uut.uut->axis_o_tvalid, uut.uut->axis_o_tlast, uut.uut->axis_o_tdata);


	AXISSource<vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&outAxis);
	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
		if(uut.eval() == false)
		{
			break;
		}
		// Break after a timeout
		#warning "This is lazy"
		if(uut.getTime() == 10000)
		{
			break;
		}
	}
	return outAxis.getData();
}

TEST_CASE("Test data comes out of FIFO", "[axis_fifo]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	REQUIRE(testFifo(testData) == testData);
}
