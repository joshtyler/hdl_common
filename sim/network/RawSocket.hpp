#ifndef RAW_SOCKET_HPP
#define RAW_SOCKET_HPP

// Send data out over a raw socket
// (later maybe receive it too)

#include <vector>
#include <net/if.h>

#include <sys/socket.h>
#include <linux/if_packet.h>
#include <net/ethernet.h> /* the L2 protocols */

#include <netinet/in.h>

struct RawSocketException : std::runtime_error
{
	using std::runtime_error::runtime_error;
};

class RawSocket
{
public:
	RawSocket(std::string interface)
	{
		// Open a raw socket
		sock = socket(AF_PACKET, SOCK_RAW, IPPROTO_RAW);
		if (sock < 0)
		{
			throw RawSocketException("Could not open raw socket. Returned: "+std::to_string(sock));
		}

		// Retreive the interaface index for our interface
		unsigned int if_idx = if_nametoindex(interface.c_str());
		if(if_idx == 0)
		{
			throw RawSocketException("Could not get interface index for interface: "+interface);
		}

		// Construct our socket address structure
		sock_addr.sll_ifindex = if_idx; // Interface index
		sock_addr.sll_halen = ETH_ALEN; // Ethernet address length
		sock_addr.sll_addr[0] = 0; // Destination MAC
		sock_addr.sll_addr[1] = 0; // N.B this is not used
		sock_addr.sll_addr[2] = 0; // Because we are using a raw socket
		sock_addr.sll_addr[3] = 0;
		sock_addr.sll_addr[4] = 0;
		sock_addr.sll_addr[5] = 0;
	};

	void send(std::vector<uint8_t> data)
	{
		int ret = sendto(sock, data.data(), data.size(), 0, (struct sockaddr*)&sock_addr, sizeof(struct sockaddr_ll));
		if (ret < 0)
		{
			throw RawSocketException("Sending failed. Returned: "+std::to_string(ret));
		}
	}

private:
	int sock;
	struct sockaddr_ll sock_addr;
};

#endif
