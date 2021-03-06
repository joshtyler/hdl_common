//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef RESET_GEN_HPP
#define RESET_GEN_HPP

// Generate a reset pulse

#include "ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include "../verilator/VerilatedModel.hpp"

class ResetGen : public Peripheral
{
public:
	ResetGen(gsl::not_null<VerilatedModelInterface *> model, gsl::not_null<ClockGen *> clk, gsl::not_null<vluint8_t *> reset, bool polarity)
		:Peripheral(model), clk(clk), reset(reset)
	{
		*reset = polarity;
	};
	void eval(void) override
	{
		if((clk->getEvent() == ClockGen::Event::RISING) and ctr < 5)
		{
			ctr = ctr + 1;
			if(ctr == 5)
			{
				*reset = ! *reset;
			}
		}
	}

private:
	ClockGen *clk;
	vluint8_t *reset;
	int ctr = 0;
};

#endif
