#!/bin/bash
whoami > /opt/whoami.txt
#install 3proxy
export DEBIAN_FRONTEND=noninteractive

LOGFILE=/opt/3proxy-install.log
# print current datetime to log (for debug)
date >> ${LOGFILE}

# install 3proxy
if [ ! -f /usr/bin/3proxy ]
then
    echo '== Install 3proxy'
	apt-get install -y -q curl net-tools gcc make libc6-dev dialog apt-utils
	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
	wget -O /opt/3proxy-0.9.3.x86_64.deb https://github.com/3proxy/3proxy/releases/download/0.9.3/3proxy-0.9.3.x86_64.deb
	dpkg -i /opt/3proxy-0.9.3.x86_64.deb && apt-get -f install
fi

# get server IP
IP_GET_ITER=0
echo '== Get external IP address ...'
while [ "${IP_GET_ITER}" -le 30 ]
do
    IPV4_ADDR=$(ip -f inet addr | grep 'inet ' | grep -v '127.0.0' | awk '{ print $2}' | cut -d/ -f1 | head -n 1)
    if [ -n "${IPV4_ADDR}" ] ;  then break; fi
    echo '... IP address empty, sleep...' &&  sleep 2
    ((IP_GET_ITER+=1))
done

# set 3proxy config
echo '== Set 3proxy config ...'
cfg_file=/etc/3proxy/conf/3proxy.cfg
cat > ${cfg_file} << EOF
daemon

nscache 65536
nserver 8.8.8.8
nserver 8.8.4.4

config /conf/3proxy.cfg
monitor /conf/3proxy.cfg

internal ${IPV4_ADDR}
external ${IPV4_ADDR}

users \$/conf/passwd

log /logs/3proxy.log H
logformat "-,\''+_L%t,""%N"",%p,%E,""%U"",""%C"",%c,""%R"",%r,%O,%I,""%n"",""%T"" "
rotate 1

include /conf/counters
include /conf/bandlimiters

auth strong
noforce
allow *
proxy -a -n -p45000
socks -a -p46000
EOF

# add crontab tasks
CRON_TASKS_EXISTS=$(grep "3proxy" '/var/spool/cron/crontabs/root' -s)
if [ -z "${CRON_TASKS_EXISTS}" ]
then     
    echo '== Set crontab tasks ...'
	PATH=$(find / -name 3proxy-install.sh -type f)
    echo "@reboot         ${PATH} >> ${LOGFILE} 2>&1" >> '/var/spool/cron/crontabs/root'
    chown root: '/var/spool/cron/crontabs/root' 
    chmod 600 '/var/spool/cron/crontabs/root'
fi

# start proxy
echo '== Running proxy ...'
/etc/init.d/3proxy start