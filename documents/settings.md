* * *
- [1.开机自启](#1开机自启)
  * [1.配置Nginx开机自启](#1配置Nginx开机自启)
  * [2.配置v2ray_ws_tls开机自启](#2配置v2ray_ws_tls开机自启)
  * [3.测试开机自启是否成功](#3测试开机自启是否成功)
- [2.开启Centos bbr拥塞控制算法[我的测试机是centos 7]](#27开启centos-bbr拥塞控制算法我的测试机是centos-7)
  * [1.检查是否安装bbr](#1检查是否安装bbr)
  * [2.yum更新](#2yum更新)
  * [3.查看系统版本](#3查看系统版本)
  * [4.安装elrepo并升级内核](#4安装elrepo并升级内核)
  * [5.更新grud文件并重启](#5更新grud文件并重启)
  * [6.开机后检查内容是否为4.9及以上版本](#6开机后检查内容是否为4.9及以上版本)
  * [7.开启bbr](#7开启bbr)
  * [8.验证bbr是否开启成功](#8验证bbr是否开启成功)
    + [测试方法1](#测试方法1)
    + [测试方法2](#测试方法2)
* * *

# 1.开机自启
## 1.配置Nginx开机自启
- 创建service文件
```
cd /etc/systemd/system&&touch nginxReboot.service
```

- 将下面内容复制到/etc/systemd/system/nginxReboot.service
```
[Unit]
Description=nginx - high performance web server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
Environment=PATH=/root/.nvm/versions/node/v12.8.1/bin:/usr/bin/v2ray/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s stop
ExecQuit=/usr/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

- 设置开机自启
```
sudo systemctl enable nginxReboot.service
```
- 可能出现的错误
```
# 可能会出现 (13: Permission denied) while connecting to upstream:[nginx]
// 解决方法 执行下面的命令
setsebool -P httpd_can_network_connect 1
```

## 2.配置v2ray_ws_tls开机自启
- 创建service文件
```
cd /etc/systemd/system&&touch v2ray_ws_tls.service
```

- 将下面内容复制到/etc/systemd/system/v2ray_ws_tls.service
```
[Unit]
Description=V2Ray WS TLS Service
After=network.target
Wants=network.target

[Service]
Type=simple
PIDFile=/run/v2rayWSTLS.pid
ExecStart=/usr/bin/v2ray/v2ray -config /root/config_ws_tls.json
Restart=on-failure
# Don't restart in the case of configuration error
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
```
- 设置开机自启
```
sudo systemctl enable v2ray_ws_tls.service
```
## 3.测试开机自启是否成功
- 重启vps
```
reboot
```
- 重启后查看程序是否正常启动
```
# 执行下方命令查看v2ray是否启动
ps -ef|grep v2ray

root      4533     1  0 03:03 ?        00:00:00 /usr/bin/v2ray/v2ray -config /root/config_ws_tls.json
root      4560  1287  0 03:04 pts/0    00:00:00 grep --color=auto v2ray

# 执行下方命令查看nginx是否启动，
ps -ef|grep nginx
``
root       762     1  0 02:20 ?        00:00:00 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
nginx      763   762  0 02:20 ?        00:00:00 nginx: worker process
root      4562  1287  0 03:04 pts/0    00:00:00 grep --color=auto nginx
```
# 2.开启Centos bbr拥塞控制算法[我的测试机是centos 7]
## 1.检查是否安装bbr
- 有一些vps会自带bbr模块 比如搬瓦工的某些机器，执行下面命令
```
lsmod | grep bbr
```
- 如果输出类似内容则已经开启bbr 到这里就可以结束了
```
tcp_bbr                20480  28
```
## 2.yum更新
```
yum update
```
## 3.查看系统版本
- 执行下面命令
```
cat /etc/redhat-release
```

- 如果release后面的数字大于7.3即可
```
CentOS Linux release 7.7.1908 (Core)
```
## 4.安装elrepo并升级内核
- 分别依次执行下面命令
```
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel install kernel-ml -y
```
- 正常情况下会输出下面内容
```
Transaction Summary
================================================================================
Install  1 Package
Total download size: 39 M
Installed size: 169 M
Downloading packages:
kernel-ml-4.9.0-1.el7.elrepo.x86_64.rpm                    |  39 MB   00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
Warning: RPMDB altered outside of yum.
  Installing : kernel-ml-4.9.0-1.el7.elrepo.x86_64                          1/1
  Verifying  : kernel-ml-4.9.0-1.el7.elrepo.x86_64                          1/1
Installed:
  kernel-ml.x86_64 0:4.9.0-1.el7.elrepo
Complete!
```
## 5.更新grud文件并重启
- 依次执行下面的命令，重启后需要等待数秒重新使用ssh连接
```
egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \'
grub2-set-default 0
reboot
```
## 6.开机后检查内容是否为4.9及以上版本
- 执行下面的命令
```
uname -r
```
- 输出结果
```
5.3.7-1.el7.elrepo.x86_64
```
## 7.开启bbr
- 执行下面的命令
```
vim /etc/sysctl.conf
```
- 添加如下内容
```
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```
- 加载系统参数
```
sysctl -p
```
## 8.验证bbr是否开启成功
### 测试方法1
- 执行下面的命令
```
sysctl net.ipv4.tcp_available_congestion_control
```
- 输出下面内容即为成功
```
net.ipv4.tcp_available_congestion_control = bbr cubic reno
```

### 测试方法2
- 执行下面的命令
```
lsmod | grep bbr
```
- 输出下面内容即为成功
```
tcp_bbr                20480  28
```

