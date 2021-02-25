//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef VERILATED_MODEL_HPP
#define VERILATED_MODEL_HPP

#include "verilated.h"
#include "verilated_vcd_c.h"
#include <string>

#include "Peripheral.hpp"
#include "../other/ClockGen.hpp"

// Class that binds together a clock generator, and a Verilated model input
class ClockBind
{
public:
	ClockBind(ClockGen &gen, vluint8_t &clk) :gen(gen), clk(clk) {};

	void eval(void) {clk = gen.getVal();};
	ClockGen &gen;
	vluint8_t &clk;
};

static bool neverBreak(void)
{
	return 0;
}

// Take care of boilerplate for a verilated model
template <class MODEL> class VerilatedModel
{
public:

	VerilatedModel(void)
	:VerilatedModel("vcd.vcd",false)
	{
	}

	VerilatedModel(int argc, char**argv, bool recordVcd)
	:VerilatedModel(std::string(argv[0])+".vcd",recordVcd)
	{
		Verilated::commandArgs(argc, argv);
	}

	VerilatedModel(std::string vcdname, bool recordVcd)
	:time(0), tfp(NULL), finishCallback(neverBreak)
	{
		uut = new MODEL;

		if (recordVcd)
		{
			Verilated::traceEverOn(true);
			tfp = new VerilatedVcdC;
			uut->trace(tfp, 99);

			std::cout << vcdname << std::endl;
			tfp->open(vcdname.c_str());
		}
		
		// Get initial state
		uut->eval();
	}

	~VerilatedModel()
	{
		delete uut;

		if (tfp != NULL)
		{
			tfp->close();
			delete tfp;
		}
	};

	void addClock(ClockBind *c) {clocks.push_back(c);};
	void addPeripheral(Peripheral *p) {peripherals.push_back(p);};
	void setFinishCallback(bool (*func)(void) ) {finishCallback = func;};

	const vluint64_t & getTime(void) {return time;};

	bool eval(void)
	{
		time++;
		for(auto c : clocks)
		{
			c->eval();
		}


		for(auto p : peripherals)
		{
			p->latch();
		}
		uut->eval();
		for(auto p : peripherals)
		{
			p->eval();
		}


		//Add this to the dump
		if (tfp != NULL)
		{
		    tfp->dump(time);
            tfp->flush();
		}

		return (!Verilated::gotFinish());
	}

	MODEL* uut;
private:
	std::vector<ClockBind *> clocks;
	std::vector<Peripheral *> peripherals;
	vluint64_t time;
	VerilatedVcdC* tfp;
	bool (*finishCallback)(void);
};

#endif
