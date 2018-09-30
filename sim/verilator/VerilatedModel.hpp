#ifndef VERILATED_MODEL_HPP
#define VERILATED_MODEL_HPP

#include "verilated.h"
#include "verilated_vcd_c.h"
#include <string>

#include "Peripheral.hpp"
#include "ClockGen.hpp"

// Class that binds together a clock generator, and a Verilated model input
class ClockBind
{
public:
	ClockBind(ClockGen &gen, vluint8_t &clk) :gen(gen), clk(clk) {};

	void eval(void) {clk = gen.getVal();};
	ClockGen &gen;
	vluint8_t &clk;
};

bool neverBreak(void)
{
	return 0;
}

// Take care of boilerplate for a verilated model
template <class MODEL> class VerilatedModel
{
public:
	VerilatedModel(int argc, char**argv, bool recordVcd)
	:time(0), tfp(NULL), finishCallback(neverBreak)
	{
		Verilated::commandArgs(argc, argv);
		uut = new MODEL;

		if (recordVcd)
		{
			Verilated::traceEverOn(true);
			tfp = new VerilatedVcdC;
			uut->trace(tfp, 99);

			std::string vcdname = argv[0];
			vcdname += ".vcd";
			std::cout << vcdname << std::endl;
			tfp->open(vcdname.c_str());
		}
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
