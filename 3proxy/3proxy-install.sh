#!/bin/bash

#install 3proxy
export DEBIAN_FRONTEND=noninteractive
wget https://github.com/3proxy/3proxy/releases/download/0.9.3/3proxy-0.9.3.x86_64.deb
dpkg -i 3proxy-0.9.3.x86_64.deb
apt-get -f install && apt-get install -y -q curl net-tools gcc make libc6-dev dialog apt-utils


# current directory
CURRDIR=$(pwd)
# 3proxy version
PROXY_VER='0.9.1'


# funcs
exit_if_not_equal_0() {
    if [ "$1" -ne '0' ]
    then
        >&2 echo -e "== $2"
        exit 1
    fi
}
exit_if_empty() {
    if [ -z "$1" ]
    then
        >&2 echo -e "== $2"
        exit 1
    fi
}

# install 3proxy
/*
if [ ! -f /usr/bin/3proxy ]
then
    echo '== Install 3proxy'

    # for non-interactive scripts
	# variant 1:
	echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
	sudo apt-get install -y -q
	sudo chmod 777 /var/cache/debconf/
	sudo chmod 777 /var/cache/debconf/passwords.dat
	
	# variant 2:
	export DEBIAN_FRONTEND=noninteractive
    
	# install reqs
	apt-get update && apt-get install -y curl net-tools gcc make libc6-dev dialog apt-utils
    exit_if_not_equal_0 "$?" 'apt install failed'

    curl -sSL "https://github.com/z3APA3A/3proxy/archive/${PROXY_VER}.tar.gz" > "${CURRDIR}/${PROXY_VER}.tar.gz"
    exit_if_not_equal_0 "$?" 'curl 3proxy failed'

    tar -zxf "${CURRDIR}/${PROXY_VER}.tar.gz"
    exit_if_not_equal_0 "$?" 'extract 3proxy failed'    

    cd "${CURRDIR}/3proxy-${PROXY_VER}/scripts" || exit_if_empty '' 'cd failed'

    chmod +x *.sh
    ./3proxy-linux-install.sh

    cd "${CURRDIR}" || exit_if_empty '' 'cd to CURRDIR failed'
fi
*/

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
pidfile /tmp/3proxy.pid
config /etc/3proxy/3proxy.cfg
internal ${IPV4_ADDR}
external ${IPV4_ADDR}
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
users \$/conf/passwd
users fastusaproxycom:CL:Fastusaproxycom8080
log /var/log/3proxy/3proxy.log H
logformat "-,\''+_L%t,""%N"",%p,%E,""%U"",""%C"",%c,""%R"",%r,%O,%I,""%n"",""%T"" "
rotate 1
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
    echo "@reboot         /etc/init.d/3proxy start >> /var/log/proxytunneler.log 2>&1" >> '/var/spool/cron/crontabs/root'
    chown root: '/var/spool/cron/crontabs/root' 
    chmod 600 '/var/spool/cron/crontabs/root'
fi

# start proxy
echo '== Running proxy ...'
/etc/init.d/3proxy start