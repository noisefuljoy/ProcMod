#include <fcntl.h>
#include <linux/input.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <oscpkt.hh>
#include <libraries/UdpClient/UdpClient.h>

std::string gOscAddress = "/key"; // OSC address. Message format: <address> <encoderId> <encoderValue>
std::string gDestinationIp = "bela.local"; // 192.168.7.1 is the host computer (if it's a Mac or Linux, it would be 192.168.6.1 if it's Windows).
int gDestinationPort = 57120;
UdpClient sock;

static void sendOsc(const std::string& subPath, int value)
{
	oscpkt::PacketWriter pw;
	pw.init();
	std::string address = gOscAddress + subPath;
	oscpkt::Message msg(address);
	pw.addMessage(msg.pushInt32(value));
	printf("%s %d\n", address.c_str(), value);
	if(pw.isOk())
		sock.send((void*)pw.packetData(), pw.packetSize());
}

int main(){
	if(!sock.setup(gDestinationPort, gDestinationIp.c_str()))
	{
		fprintf(stderr, "Unable to send to %s:%d\n", gDestinationIp.c_str(), gDestinationPort);
		return 1;
	}

	// Variables keyboard control
	struct input_event ev;
	const char *dev = "/dev/input/event1";

	// qwerty keyboard capture
	int fd = open(dev, O_RDONLY);
	if (fd == -1) {
		fprintf(stderr, "Cannot open %s:.\n", dev);
		return -1;
	}
	while (1)
	{
		ssize_t n = read(fd, &ev, sizeof ev);
		if (n < 0) {
			fprintf(stderr, "Error while reading: %d %s\n", errno, strerror(errno));
			return -1;
		} else if (n != sizeof(ev)) {
			fprintf(stderr, "Read unexpected length\n");
			return -1;
		} else {
			if (ev.type == EV_KEY && ev.value == 0 && ev.value <= 2)
			{
				// key released
				sendOsc("/released", ev.code);
			}
			if (ev.type == EV_KEY && ev.value == 1 && ev.value <= 2)
			{
				// key pressed
				sendOsc("", ev.code);
			}
		}
	}
	close(fd); // won't actually get here unless an error occurs
	return 0;
}