#include "GMIISink.hpp"

#include <sstream>
#include <zlib.h>
#include <iostream>

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
            if(ipg_counter)
            {
                GMIISinkException("Violation of inter packet gap. " + std::to_string(ipg_counter)+" cycles remain");
            }

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

            if(iter == current_packet.end())
            {
                throw GMIISinkException("No SFD");
            }

            if(*(iter++) != 0xD5)
            {
                throw GMIISinkException("No SFD / SFD has incorrect value");
            }

            if((current_packet.end() - iter) < 64)
            {
                throw GMIISinkException("Packet is too small");
            }

            uint32_t crc_calc = crc32(0x0, &(*iter), current_packet.end()-iter-4);
            uint32_t crc_hdl = *reinterpret_cast<uint32_t *>(&(*(current_packet.end()-4)));
            if(crc_calc != crc_hdl)
            {
                std::stringstream ss;
                ss << std::hex;
                ss << "CRC is incorrect. HDL Says: " << crc_hdl << ' ';
                ss << "CPP says: " << crc_calc << '\n';
                throw GMIISinkException(ss.str());
            }

            data_sink->send(std::span(iter, current_packet.end())); // Send CRC as well. Wireshark will check it for us :)

            current_packet.clear();
            ipg_counter = 12;
        }
    }
}

