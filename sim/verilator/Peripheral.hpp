//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef PERIPHERAL_HPP
#define PERIPHERAL_HPP

#include <gsl/pointers>

// We have a base class to allow us to have a vector of pointers, without the template parameter
class InputLatchBase
{
public:
	virtual void latch(void) = 0;
};

// Class to store the value of an input when latch is called
template <class T> class InputLatch : public InputLatchBase
{
public:
	InputLatch(const T* ref) :ref(ref) {latch();};
    void latch(void) override {if(ref) saved = *ref;};
    T operator *() const {return ref? saved : T{};};
    bool is_null(void) {return !ref;}
private:
	const T* ref;
	T saved;
};

// Base class for Verilator peripherals
// Handles latching of inputs
// Before the clock latch() is called on the verilated model, and after the clock eval() is called
// This saves the previous values of the inputs and makes it look to the peripheral like it has the values of inputs before the clock edge
class Peripheral
{
public:
    virtual ~Peripheral() = default;

	// Save inputs to Peripheral
	// The overriding class adds all its inputs to the latch queue during construction
	void latch(void)
	{
		for(auto itm : inputs)
		{
			itm->latch();
		}
	}

	void addInput(InputLatchBase *i) {inputs.push_back(i);};

	// Update outputs from peripheral
	virtual void eval(void) = 0;

private:
	std::vector<InputLatchBase *> inputs;
};

#endif
