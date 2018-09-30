#ifndef PERIPHERAL_HPP
#define PERIPHERAL_HPP

// This is a class to latch inputs to a peripheral
// It is called just eval() is called on the verilated model
// This saves the previous values of the inputs
// It allows us to call eval() on our Peripheral, as if it was occuring at the same clock edge as the verilated eval()

// We have a base class to allow us to have a vector of references, without the template parameter
class InputLatchBase
{
public:
	virtual void latch(void) = 0;
};

template <class T> class InputLatch : public InputLatchBase
{
public:
	InputLatch(const T& ref) :ref(ref) {latch();};
	~InputLatch() {};
	void latch(void) override {saved = ref;};
	operator T() {return saved;};
private:
	const T &ref;
	T saved;
};

// Virtual base class for Verilator peripherals
class Peripheral
{
public:
	Peripheral() {};
	~Peripheral() {};

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
