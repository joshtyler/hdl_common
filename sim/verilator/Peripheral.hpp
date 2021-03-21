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

// Forward declare to avoid circular include
class VerilatedModelInterface;

// We have a base class to allow us to have a vector of pointers, without a template parameter
class InputLatchBase
{
public:
    virtual void latch(void) = 0;
};

// Base class for Verilator peripherals
// Handles latching of inputs
// Before the clock latch() is called on the verilated model, and after the clock eval() is called
// This saves the previous values of the inputs and makes it look to the peripheral like it has the values of inputs before the clock edge
class Peripheral
{
public:
    Peripheral(gsl::not_null<VerilatedModelInterface *> model);
    virtual ~Peripheral() = default;

	// Save inputs to Peripheral
	// The overriding class adds all its inputs to the latch queue during construction
	void latch(void);

    // Update outputs from peripheral
    virtual void eval(void) = 0;

    // Input addition should only be done for class members
    // And it is important that they do not change location after registering!
    // Removal is permitted to allow inputs to be moved (e.g. for a vector of inputs)
	void addInput(InputLatchBase *i);

    void removeInput(InputLatchBase *i);

private:
	std::vector<InputLatchBase *> inputs;
};


// Class to store the value of an input when latch is called
// Registers itself with the peripheral so that the user cannot forget
// Also takes a default value in the constructor, if ref is null, this default_value will always be returned
// This makes for clean interfaces for optional signals
template <class T> class InputLatch : public InputLatchBase
{
public:
    InputLatch(gsl::not_null<Peripheral *> parent_, const T* ptr_, T default_value=T{})
        :parent(parent_), ptr(ptr_), saved(default_value)
    {
        // Register ourselves so that our parent calls latch at the right time
        parent->addInput(this);

        // Store an initial value
        latch();
    };

    ~InputLatch()
    {
        parent->removeInput(this);
    }

    InputLatch(const InputLatch &other)
        :parent(other.parent), ptr(other.ptr), saved(other.saved)
    {
        parent->addInput(this);
    }

    void latch(void) override {if(ptr) saved = *ptr;};
    operator T() const {return saved;};
    bool is_null(void) {return !ptr;}
private:
    Peripheral *parent;
    const T* ptr;
    T saved;
};

// Class to wrap a raw pointer for the output
// Writes are ignored if initialised with nullptr
template <class T> class OutputWrapper
{
public:
    OutputWrapper(T* ptr_) : ptr(ptr_) {};
    inline const T& operator=(const T& other)
    {
        if(ptr)
        {
            *ptr = other;
        }
        return other;
    };
    inline operator T() const {return ptr ? *ptr : T{};};
    bool is_null(void) {return !ptr;}
private:
    T* ptr;
};

#endif
