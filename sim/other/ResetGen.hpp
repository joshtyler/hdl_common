#ifndef RESET_GEN_HPP
#define RESET_GEN_HPP

// Generate a reset pulse

#include "ClockGen.hpp"
#include "Peripheral.hpp"

class ResetGen : public Peripheral
{
public:
	ResetGen(ClockGen &clk, vluint8_t &reset, bool polarity)
		:clk(clk), reset(reset), ctr(0)
	{
		reset = polarity;
	};
	void eval(void) override
	{
		if((clk.getEvent() == ClockGen::Event::RISING) and ctr < 5)
		{
			ctr = ctr + 1;
			if(ctr == 5)
			{
				reset = ! reset;
			}
		}
	}

private:
	ClockGen &clk;
	vluint8_t &reset;
	int ctr;
};

#endif
