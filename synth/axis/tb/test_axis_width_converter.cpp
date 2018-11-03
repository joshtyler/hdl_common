#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vaxis_width_converter_1i_1o.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

template <class model_t, class data_in_t, class data_out_t> auto testWidthConverter(std::vector<std::vector<data_in_t>> inData)
{
	VerilatedModel<model_t> uut;

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	AXISSource<data_in_t,vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	AXISSink<data_out_t,vluint8_t> outAxis(clk, uut.uut->sresetn, uut.uut->axis_o_tready,
		uut.uut->axis_o_tvalid, uut.uut->axis_o_tlast, uut.uut->axis_o_tdata);


	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&outAxis);
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

TEST_CASE("Test width converter pass through", "[axis_width_converter]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	auto result = testWidthConverter<Vaxis_width_converter_1i_1o,vluint8_t, vluint8_t>(testData);
	REQUIRE(testData == result);
}
