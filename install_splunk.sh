#!/bin/sh
# This script must be run with root privileges.
# This script requires two arguments: the Splunk installation tarball and method to execute (install_splunk,configure_splunk_user,check_ulimits_thp,tune_ulimits_thp).

INSTALL_USER_HOME="/home/ec2-user"
SPLUNK_INSTALL_DIR="/opt"
SPLUNK_HOME="${SPLUNK_INSTALL_DIR}/splunk"
PROCESS=$1

# Grab tarball and store in home directory
cd ${INSTALL_USER_HOME}

# Install Splunk, start Splunk, enable boot-start, change admin password.
install_splunk () {	
	#TARBALL=$2
	useradd splunk
	#tar xvf ${TARBALL} -C ${SPLUNK_INSTALL_DIR}
	usermod -d ${SPLUNK_HOME} splunk	
	
	${SPLUNK_HOME}/bin/splunk start --accept-license
	${SPLUNK_HOME}/bin/splunk stop
	
	${SPLUNK_HOME}/bin/splunk enable boot-start -user splunk
	chown -R splunk:splunk ${SPLUNK_HOME}	
	echo "Success! Splunk installed."
	echo
}


# Create Splunk user with home directory.
configure_splunk_user () {
	cat >${SPLUNK_HOME}/.bash_profile <<EOF
# .bash_profile

if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User-specific environment and startup programs
PATH=$PATH:$HOME/bin

export PATH
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$ '
EOF
	chown -R splunk:splunk ${SPLUNK_HOME}/.bash_profile
	source ${SPLUNK_HOME}/.bash_profile
	echo "Configured Splunk bash_profile."
}


check_ulimits () {
	if [ -f /etc/security/limits.conf ]; then
		if [[ $(cat /etc/security/limits.conf | grep splunk) ]]; then
			echo
			echo "Displaying Splunk user limits from limits.conf..."
			echo
			cat /etc/security/limits.conf | grep splunk
			echo
		else
			echo "No Splunk user limits defined."
		fi
	fi
}


check_thp_disabled () {
	THP=`find /sys/kernel/mm/ -name *transparent_hugepage -type d | tail -n 1`
	if [ -d ${THP} ]; then
		echo "Displaying current THP settings..."
		cat /${THP}/enabled
		cat /${THP}/defrag
		echo
	fi
	if [ -f /etc/rc.local ]; then
		echo "Displaying contents of rc.local..."
		cat /etc/rc.local
		echo
	fi
}

tune_ulimits () {
	if [ -f /etc/security/limits.conf ]; then
		cat >>/etc/security/limits.conf <<EOF

splunk hard core 0
splunk hard maxlogins 10
splunk soft nofile 65535
splunk hard nofile 65535
splunk soft nproc 20480
splunk hard nproc 20480
splunk soft fsize unlimited
splunk hard fsize unlimited
EOF
	fi
}

disable_thp () {
	THP=`find /sys/kernel/mm/ -name *transparent_hugepage -type d | tail -n 1`
        for SETTING in "enabled" "defrag"; do
		if [ -f ${THP}/${SETTING} ]; then
			echo never > ${THP}/${SETTING} 
		fi
	done

       if [ -f /etc/rc.local ]; then
		cat >>/etc/rc.local <<EOF

THP=`find /sys/kernel/mm/ -name *transparent_hugepage -type d | tail -n 1`
for SETTING in "enabled" "defrag"; do
	if [ -f ${THP}/${SETTING} ]; then
		echo never > ${THP}/${SETTING}
	fi
done
EOF
        fi
}

if [ ${PROCESS} == "install_splunk" ]; then
	# Ensure user has provided tar file as an argument to script.
	#if [ $# -lt 2 ]; then
	#	echo "Please supply path to Splunk tarball."
	#	exit
	#fi
	install_splunk
elif [ ${PROCESS} == "configure_splunk_user" ]; then
	configure_splunk_user
elif [ ${PROCESS} == "check_ulimits_thp" ]; then
	check_ulimits
	check_thp_disabled
elif [ ${PROCESS} == "tune_ulimits_thp" ]; then
	tune_ulimits
	disable_thp
fi

#sudo su - splunk
#${SPLUNK_HOME}/bin/splunk start
