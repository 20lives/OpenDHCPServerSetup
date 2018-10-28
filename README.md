# DHCP Server - Setup script

In order to connect to the Studio machine in each HLK/HCK setup, we need to set up a DHCP server that will provide each studio with a unique IP address.  The server will assign the IP address according to the machine mac address with the following rule (replace XX with AutoHCK unique ID):

56:00:XX:00:XX:dd > 192.168.0.XX

Run `opendhcpserverSetup.sh` with sudo, (root privileges), to download openDHCP, install it as a service and configure it with the required IP assignment rule.

The script will also create a new bridge named 'br1'. If this bridge is already used, you can change its name.

NOTE: you will need to change it accordingly in auto_hck config file.
