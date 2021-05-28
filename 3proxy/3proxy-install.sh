#!/bin/bash

#install 3proxy
wget https://github.com/3proxy/3proxy/releases/download/0.9.3/3proxy-0.9.3.x86_64.deb
sudo dpkg -i 3proxy-0.9.3.x86_64.deb
sudo apt-get -f install

# get server IP
IP_GET_ITER=0
while [ "${IP_GET_ITER}" -le 30 ]
do
    IPV4_ADDR=$(ip -f inet addr | grep 'inet ' | grep -v '127.0.0' | awk '{ print $2}' | cut -d/ -f1 | head -n 1)
    if [ -n "${IPV4_ADDR}" ]
    then
        break
    fi

    echo '== IP address empty, sleep...'
    sleep 2

    ((IP_GET_ITER+=1))
done

# set 3proxy config
cfg_file=/etc/3proxy/conf/3proxy.cfg
sudo cat > ${cfg_file} << EOF
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
CRON_TASKS_EXISTS=$(sudo grep "3proxy" '/var/spool/cron/crontabs/root' -s)

if [ -z "${CRON_TASKS_EXISTS}" ]
then    
    # run after system reboot
    sudo echo "@reboot         /etc/init.d/3proxy start >> /var/log/proxytunneler.log 2>&1" >> '/var/spool/cron/crontabs/root'

    sudo chown root: '/var/spool/cron/crontabs/root' 
    sudo chmod 600 '/var/spool/cron/crontabs/root'
fi

sudo /etc/init.d/3proxy start