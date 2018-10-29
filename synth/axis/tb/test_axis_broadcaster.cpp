#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vaxis_broadcaster_harness.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

auto testBroadcaster(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_broadcaster_harness> uut;

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	AXISSource<vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	AXISSink<vluint8_t> outAxis1(clk, uut.uut->sresetn, uut.uut->axis_o1_tready,
		uut.uut->axis_o1_tvalid, uut.uut->axis_o1_tlast, uut.uut->axis_o1_tdata);

	AXISSink<vluint8_t> outAxis2(clk, uut.uut->sresetn, uut.uut->axis_o2_tready,
		uut.uut->axis_o2_tvalid, uut.uut->axis_o2_tlast, uut.uut->axis_o2_tdata);


	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&outAxis1);
	uut.addPeripheral(&outAxis2);
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
		if(uut.getTime() == 10000)
		{
			break;
		}
	}
	//return outAxis.getData();
	std::array<std::vector<std::vector<vluint8_t>>, 2> outArr;
	outArr[0] = outAxis1.getData();
	outArr[1] = outAxis2.getData();
	return outArr;
}

TEST_CASE("Test all re-broadcasted streams are correct", "[axis_broadcaster]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	std::array<std::vector<std::vector<vluint8_t>>,2> outData = {testData, testData};
	testBroadcaster(testData);
	REQUIRE( outData == outData);
}
