#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   System Required:  CentOS 7                                    #
#   Description: One click Install UML for bbr+ssr                #
#   Author: 91yun <https://twitter.com/91yun>                     #
#   Thanks: @allient neko @Jacky Bao                              #
#   Intro:  https://www.91yun.org                                 #
#=================================================================#

yum install -y tunctl uml-utilities screen

#下载uml版centos6
wget http://hfck.tk/uml-centos-64.tar.gz
#http://blog.hfck.tk/uml-centos-64.tar.gz 00066+cloudfare
#http://go.hfck.tk/uml-centos-64.tar.gz 00088+cloudfare
#http://hfck.tk/uml-centos-64.tar.gz zly+cloudfare
#http://zblog.ck66.xin/uml-centos-64.tar.gz zly+tencent
#https://hlck.tk/uml-centos-64.tar.gz zly+cloudfare
tar zfvx uml-centos-64.tar.gz
cd uml-centos-64
cur_dir=`pwd`

#创建run.sh，并赋予执行权限
cat > run.sh<<-EOF
#!/bin/sh
export HOME=/root
start(){
	ip tuntap add tap1 mode tap 
	ip addr add 10.0.0.1/24 dev tap1 
	ip link set tap1 up 
	echo 1 > /proc/sys/net/ipv4/ip_forward
	iptables -P FORWARD ACCEPT 
	iptables -t nat -A POSTROUTING -o venet0 -j MASQUERADE
	iptables -I FORWARD -i tap1 -j ACCEPT
	iptables -I FORWARD -o tap1 -j ACCEPT
	iptables -t nat -A PREROUTING -i venet0 -p tcp --dport 9191 -j DNAT --to-destination 10.0.0.2
	iptables -t nat -A PREROUTING -i venet0 -p udp --dport 9191 -j DNAT --to-destination 10.0.0.2
	screen -dmS uml ${cur_dir}/vmlinux ubda=${cur_dir}/CentOS64_fs eth0=tuntap,tap1 mem=256m
	ps aux | grep vmlinux
}

stop(){
    kill \$( ps aux | grep vmlinux )
	ifconfig tap1 down
}

status(){

	screen -r \$(screen -list | grep uml | awk 'NR==1{print \$1}')
	
}
action=\$1
#[ -z \$1 ] && action=status
case "\$action" in
'start')
    start
    ;;
'stop')
    stop
    ;;
'status')
    status
    ;;
'restart')
    stop
    start
    ;;
*)
    echo "Usage: \$0 { start | stop | restart | status }"
    ;;
esac
exit
EOF

chmod +x run.sh

#创建和uml的共享目录
mkdir -p /root/umlshare

#启动uml系统和ssr服务
bash run.sh start

#添加bash run.sh start到rc.local
echo "/bin/bash ${cur_dir}/run.sh start" >> /etc/rc.d/rc.local
sed -i "s/exit 0/ /ig" /etc/rc.local
chmod +x /etc/rc.d/rc.local

#下载服务文件，添加到系统服务，并随机启动
wget --no-check-certificate https://raw.githubusercontent.com/ck66/uml/master/bbr/ssr -O /etc/init.d/ssr
cp /etc/init.d/ssr /bin/
chmod +x /etc/init.d/ssr
chmod +x /bin/ssr
chkconfig --add ssr
chkconfig ssr on

#验证安装是否成功
umlstatus=$(ps aux | grep vmlinux)
if [ "$umlstatus" == "" ]; then
	echo "some thing error!"
else
	echo "uml install success!"
fi
