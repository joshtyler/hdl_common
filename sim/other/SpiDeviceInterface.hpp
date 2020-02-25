#ifndef SPI_DEVICE_INTERFACE_HPP
#define SPI_DEVICE_INTERFACE_HPP

template <class dataT> class SpiDeviceInterface
{
	public:
		// Called when SS goes low
		// Return is the data to output
		virtual dataT ss_fall() = 0;

		// Return is what to transfer next
		// Arg is what has just been received
		virtual dataT transfer(dataT rx) = 0;

		// Called when SS goes high
		virtual void ss_rise() = 0;
};

#endif
