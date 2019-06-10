//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef CLOCK_GEN_HPP
#define CLOCK_GEN_HPP

// Generate a clock for verilator testbenches
// Just takes a reference to the current time

#include "verilated.h"

class ClockGen
{
public:
	enum class Event {NONE, RISING, FALLING};
	ClockGen(const vluint64_t &count_in, double resolution, double freq)
		:count(count_in), ticksPerClock(round((1.0/freq)*(1.0/resolution))) {};
	bool getVal(void) {updateTime(); return val;};
	Event getEvent(void) {updateTime(); return event;}
	std::string eventToStr(Event e) const
	{
		switch(e)
		{
			case Event::NONE:
				return "NONE";
			case Event::RISING:
				return "RISING";
			case Event::FALLING:
				return "FALLING";
			default:
				break;
		}
		return "Error. Unknown option.";
	}
private:
	const vluint64_t &count;
	bool val;
	Event event;
	const unsigned int ticksPerClock;

 	void updateTime(void)
	{
		// Fall on remainder = 0
		// Rise on remainder >= ticksPerClock/2
		unsigned int remainder = count % ticksPerClock;
		event = Event::NONE;

//		std::cout << "(Count" << count << std::endl;
//		std::cout << "Remainder" << remainder << std::endl;

		// Set val
		if(remainder < (ticksPerClock/2))
		{
			val = false;
			if(remainder == 0)
			{
				event = Event::FALLING;
			}
		} else {
			val = true;
			if (remainder == ticksPerClock/2)
			{
				event = Event::RISING;
			}
		}
	}
};

#endif
