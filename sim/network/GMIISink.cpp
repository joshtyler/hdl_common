#include "GMIISink.hpp"

#include <zlib.h>

void GMIISink::eval(void)
{
    if((clk->getEvent() == ClockGen::Event::RISING))
    {
        if(ipg_counter)
        {
            ipg_counter--;
        }

        if(eth_txer)
        {
            // There was a line error, clear out the packet, but don't send to sink
            current_packet.clear();
        } else if(eth_txen) {
            // Data is valid -- append to data
            current_packet.push_back(eth_txd);
        } else if(current_packet.size()) {
            // Data is not valid, but current_packet contains data
            // Therefore this is the first beat since the end of packet

            // Check that we got the whole preamble
            auto iter = current_packet.begin();
            while(iter != current_packet.end() && ((*iter) == 0x55))
            {
                iter++;
            }
            if((iter - current_packet.begin()) < 7)
            {
                throw GMIISinkException("Not enough preamble bytes");
            }

            if(iter++ == current_packet.end())
            {
                throw GMIISinkException("No SFD");
            }

            if(*(iter++) == 0xD5)
            {
                throw GMIISinkException("No SFD / SFD has incorrect value");
            }

            if((current_packet.end() - iter) < 64)
            {
                throw GMIISinkException("Packet is too small");
            }

            uint32_t crc = crc32(0, &(*iter), current_packet.end()-iter);
            if(crc)
            {
                throw GMIISinkException("CRC is incorrect");
            }

            data_sink->send(std::span(iter, current_packet.end()-4));
            ipg_counter = 12;
        }
    }
}

