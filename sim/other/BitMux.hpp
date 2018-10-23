#ifndef BITMUX_HPP
#define BITMUX_HPP

#include "../verilator/Peripheral.hpp"

// Often it is useful in Verilog to pack data outupts
	// E.g. Pack the ready signals of 4 AXI busses into a 4 bit vector
// This is silghtly awkward to handle in C++, because we see that as one variable, and need to send different bits to different classes
// These are helper classes.
 	// BitMuxIn takes a const reference to a variable, and returns only the bits we care about to the upstream application
 	// BitMuxOut takes a variable from the upstream application, and updates the variable

template <class Tvlog, class Tcpp> class BitMux
{
public:
	BitMux(Tvlog& ref, unsigned int lowBit,unsigned int highBit) :ref(ref), lowBit(lowBit), highBit(highBit) {};

	BitMux(const BitMux<Tvlog, Tcpp> &other) :ref(other.ref), lowBit(other.lowBit), highBit(other.highBit) {};
	// This is used to get the value of ref
	operator Tcpp() const
	{
		Tvlog temp = ref;
		// Shift low bit to LSB
		temp >>= lowBit;
		// Mask off any bits higher than MSB
		temp &= 2^(highBit - lowBit + 1)-1;
		Tcpp ret = (Tcpp) temp;
		assert(ret == temp);
		return ret;
	};

	// This is used to set the value of ref
	// Note that we don't allow chaining because it could introduce non obvious behaviour
	void operator=(const Tcpp& other)
	{
		ref = (Tvlog) other; //Temp
	}


private:
	Tvlog &ref;
	const unsigned int lowBit, highBit;
};

#endif
