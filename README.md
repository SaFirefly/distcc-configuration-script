#Distcc configuration script

Distcc is a program to distribute builds of C, C++, Objective C or Objective C++ code across several machines on a network.

This script automates the procedure of configuring clients and servers machines.

The script has been tested with Ubuntu as a client or as a server, and Fedora as a Client.

If you find redundancies, your favorite Linux distribution is not supported, code optimisation, or any other issue,  you are welcome to make changes.

Example of runing a C distributed build (httpd Apache's project)

cd ~/httpd-2.4.12
CC=distcc ./configure
make -j16 CC=distcc 2> errors.err

-j16 is the number of parallel builds
2> is the error output

To run the text monitor: distccmon-text 1
1 number of seconds before refresh

To run the GUI monitor: distccmon-gnome


For more informations you can contact me by email: <salimb2h@gmail.com>
