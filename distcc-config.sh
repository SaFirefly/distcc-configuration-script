#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#    To contact the original author please send an email to <salimb2h@gmail.com>

#!/bin/bash

#Checks if an IP adress is IPV4 or not
valid-ip(){
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

config-server-fedora() {

	#NEEDS TESTING
	
	#Install distcc if it doesn't already exist (just the server)
	yum install -y distcc-server
	
	#Get non-root user, the user that will compile files coming from client
	#Distcc evidently doesn't allow distant machine to use this fedora machine as root
        printf "Enter your non-root user name\n"
        read user
        #Get client IP adress
        while true; do
                printf "Enter client's IP adress\n"
                read client_ip_adress
                if valid-ip $client_ip_adress; then break; fi
        done
	
	#Configure /etc/sysconfig/distccd to allow distant machine to use it
	printf "USER=\"$user\"\n" >> /etc/sysconfig/distccd
	printf "OPTIONS=\"--jobs 16 --allow ${client_ip_adress}/24 --log-file=/tmp/distccd.log --port 3632\"\n">> /etc/sysconfig/distccd
	#Starts the distccd server
	service distccd start

	##Or can be started manually by##
	#default --port 3632 
	#distccd --daemon --user $user --jobs 16 --allow "$client_ip_adress/24" --log-file=/tmp/distccd.log
	#uncomment next line to checkis it started successfully
	#ps -awwx | grep distccd
	#sleep 5
	#printf "check the log file /tmp/distccd.log\n"
	#sleep 2
	
	#Configuring firewall
	printf "Configuring Firewall\n"
	sleep 2
	#Add the new configuration line to the top of the file
	file_content=$(</etc/sysconfig/iptables)
	#Open port 3632 to tcp protocol by adding next line to /etc/sysconfig/iptables
	echo '-A INPUT -m state --state NEW -m tcp -p tcp --dport 3632 -j ACCEPT'>/etc/sysconfig/iptables
        printf "$file_content" >> /etc/sysconfig/iptables
}

config-client-fedora() {

	#yum install lsb_release
	#Install distcc if it doesn't already exist (just the client)
 	yum install -y distcc
	
	#Get list of servers IP on which compiling is going to take place
	while true; do
 		printf "Enter servers IP's with space seperated\n"
		read servers_ip_adresses
		IFS=' ' read -ra ADDR <<< "$servers_ip_adresses"
		for i in "${ADDR[@]}"; do
			if ! valid-ip $i; then continue 2; fi
		done
		break
	done
	#Remove previous configurations by removing any line that starts with an IP adress in /etc/distcc/hosts
	sed -i '/^[0-9l]/d' /etc/distcc/hosts	
	#Add allowed IP adresses to /etc/distcc/hosts
	#/16 is the number of parallel jobs given to each machine
	#lzo is the compression algorithme used
	for i in "${ADDR[@]}"; do
		printf "$i/16,lzo\n">>/etc/distcc/hosts
	done
	#localhost is always added by default
	printf "localhost/16\n">>/etc/distcc/hosts
}

config-server-ubuntu () {
	
	#Get non-root user, the user that will compile files coming from client
	#Distcc evidently doesn't allow distant machine to use this ubuntu machine as root
	printf "Enter your non-root user name\n"
	read user
	#Get the client IP adress
	#IP adress must be IPV4
	while true; do
		printf "Enter client's IP adress\n"
		read client_ip_adress
		if valid-ip $client_ip_adress; then break; fi
	done
	#Get the name of the client machine
	printf "Enter client's Machine name\n"
	read client_machine_name

	#Start the distcc server (Default port is 3632)
	distccd --daemon --user $user --allow $client_ip_adress
	#uncomment ps to check if distcc server really started 	
	#ps -ef | grep distccd
	
	#Remove previous configurations by removing any line that contains ALLOWEDNETS in /etc/default/distcc
	sed -i '/ALLOWEDNETS/d' /etc/default/distcc
	#Add the new line containing client's IP adress
	printf "ALLOWEDNETS=\"$client_ip_adress\"" >> /etc/default/distcc
	#uncomment to check if permission was granted
	#netstat -an | grep 3632
	
	#Set the DISTCC_HOSTS env var, not necessary, may be removed
	export DISTCC_HOSTS="$client_ip_adress"
	#Add client's IP adress to /etc/distcc/hosts
	printf "$client_ip_adress\n" >> /etc/distcc/hosts

	#Add client's IP adress and name to /etc/hosts
	#Add to top of the file
	aux_file=$(</etc/hosts)	
	printf "$client_ip_adress\t$client_machine_name\n" > /etc/hosts
	printf "$aux_file\n" >> /etc/hosts
}

#Configuring ubuntu client
config-client-ubuntu () {

	#Get list of servers IP on which compiling is going to take place
	#IP adresses must be IPV4
        while true; do 
                printf "Enter servers IP's with space seperated\n"
                read servers_ips
                IFS=' ' read -ra ADDR <<< "$servers_ips"
                for i in "${ADDR[@]}"; do 
                        if ! valid-ip $i; then continue 2; fi
                done
                break
        done
	#/etc/distcc/hosts is the file that holds which servers this ubuntu client is going to use
        #Init previous configurations by deleting any line that isn't a comment
        sed -i '/^[0-9l]/d' /etc/distcc/hosts
        
	#Add allowed IP adresses to /etc/distcc/hosts
	#/16 is the number of parallel jobs given to each machine
	#lzo is the compression algorithme used
        for i in "${ADDR[@]}"; do
                printf "$i/16,lzo\n">>/etc/distcc/hosts
        done
	#localhost is always added by default
        printf "localhost/16\n">>/etc/distcc/hosts
}

#Get the name of the running operating system 
os=$(lsb_release -si)
#If the running OS is Fedora
if [ $os = "Fedora" ]; then
	printf "***Fedora***\n"
	
	#Choice of configuring Server or Client 
	while true; do
    		read -p "Do you want to configure Server or Client (S/C)? " yn
    		case $yn in
        		[Ss]* ) config-server-fedora; break;;
        		[Cc]* ) config-client-fedora; break;;
        		* ) echo "Please answer S or C.";;
    		esac
	done
#If the running OS is Ubuntu
elif [ $os = "Ubuntu" ]; then
	printf "***Ubuntu***\n"
	#Install distcc if it doesn't already exist
	apt-get install -y distcc
	#Choice of configuring Server or Client
	while true; do
		read -p "Do you want to configure Server or Client (S/C)? " yn
	        case $yn in
		[Ss]* ) config-server-ubuntu; break;;
                [Cc]* ) config-client-ubuntu; break;;
                * ) echo "Please answer S or C.";;
	esac
	done

else
	printf "Your distro is neither Fedora nor Ubuntu\nYou are welcome to add your distro\n"

fi
