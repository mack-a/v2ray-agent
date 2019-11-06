# v2ray-network
本项目旨在更好的学习新知识，采用CDN+TLS+Nginx+v2ray进行伪装并突破防火墙。

# 技能点列表
- [bandwagonhost[centos7]链接一](https://bandwagonhost.com)
- [bandwagonhost[centos7]链接二](https://bwh1.net)【境外vps或者其他vps厂商】
- [cloudflare](cloudflare.com)【CDN】
- [godaddy](https://www.godaddy.com/)【域名厂商】
- [letsencrypt](https://letsencrypt.org/)【HTTPS】
- [Nginx](https://www.nginx.com/)【反向代理】
- [v2ray](v2ray.com)【代理工具】

# 1.准备工作
## 1.注册[cloudflare](cloudflare.com)
## 2.注册[godaddy](https://www.godaddy.com/)并购买域名
- 域名可选择xyz结尾的国际域名，可采用多字符乱码的方式组合域名，(比如wk1c.xyz)首年大概8RMB左右，第二年可以直接买一个新的。

## 3.修改godaddy域名的DNS解析
### 1.登录cloudflare，添加域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare.png" width=400>

### 2.选择套餐
- 如果仅仅只享受科学上网功能，选择free即可
- 如果需要更好的网络环境、更快的速度，可选择相应的套餐
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_plan.png" width=400>

### 3.根据提示修改godaddy的dns解析
- cloudflare提示界面
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_dns.png" width=400>

- godaddy DNS管理，根据上面的cloudflare提示界面修改为相应的dns
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/godayddy_dns.png" width=400>

## 4.增加cloudflare域名解析
- 添加域名解析(记录)，可以选择二级域名，这样就可以一个月解析到不同的服务器，name填写你要解析的二级域名的host部分，比如ls.example.com 只填写ls即可
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_record_dns.png" width=400>

## 5.修改godaddy SSL/TLS
- 如果vps选择使用https，需要把类型修改为Full
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_tls.png" width=400>

# 2.vps配置Nginx、https
## 1.安装Nginx
```
yum install nginx
```
## 2.nginx配置文件

- 1.下载配置文件并替换默认文件
```
cd /etc/nginx&&rm -rf /etc/nginx/nginx.conf&&wget https://raw.githubusercontent.com/mack-a/v2ray-agent/master/config/nginx.conf
# 如果缺少wget 则执行下面的命令，然后重复上面的命令
yum install wget
```
- 将下载好的文件中关于ls.xxx.xyz的内容都替换成你的二级域名

## 3.生成https

- 1.安装acme.sh
```
curl https://get.acme.sh | sh
% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                               Dload  Upload   Total   Spent    Left  Speed
100   671  100   671    0     0    680      0 --:--:-- --:--:-- --:--:--   679
% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                               Dload  Upload   Total   Spent    Left  Speed
100  112k  100  112k    0     0   690k      0 --:--:-- --:--:-- --:--:--  693k
[Fri 30 Dec 01:03:32 GMT 2016] Installing from online archive.
[Fri 30 Dec 01:03:32 GMT 2016] Downloading https://github.com/Neilpang/acme.sh/archive/master.tar.gz
[Fri 30 Dec 01:03:33 GMT 2016] Extracting master.tar.gz
[Fri 30 Dec 01:03:33 GMT 2016] Installing to /home/user/.acme.sh
[Fri 30 Dec 01:03:33 GMT 2016] Installed to /home/user/.acme.sh/acme.sh
[Fri 30 Dec 01:03:33 GMT 2016] Installing alias to '/home/user/.profile'
[Fri 30 Dec 01:03:33 GMT 2016] OK, Close and reopen your terminal to start using acme.sh
[Fri 30 Dec 01:03:33 GMT 2016] Installing cron job
no crontab for user
no crontab for user
[Fri 30 Dec 01:03:33 GMT 2016] Good, bash is found, so change the shebang to use bash as preferred.
[Fri 30 Dec 01:03:33 GMT 2016] OK
[Fri 30 Dec 01:03:33 GMT 2016] Install success!
```

- 2.生成https证书
```
# 替换ls.xxx.xyz为自己的域名
sudo ~/.acme.sh/acme.sh --issue -d ls.xxx.xyz --standalone -k ec-256

# 如果提示Please install socat tools first.则执行，安装完成后继续重复执行上面的命令
yum install socat
```

- 3.安装证书
```
# 替换ls.xxx.xyz为自己的域名
~/.acme.sh/acme.sh --installcert -d ls.xxx.xyz --fullchainpath /etc/nginx/ls.xxx.xyz.crt --keypath /etc/nginx/ls.xxx.xyz.key --ecc
```

- 4.修改/etc/nginx/nginx.conf
```
# 将下面这部分前面的#去掉，并将ssl_certificate、ssl_certificate_key修改成自己的路径

# ssl on;
# ssl_certificate /etc/nginx/ls.xx.xyz.crt;
# ssl_certificate_key /etc/nginx/ls.xx.xyz.key;
# ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
# ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
# ssl_prefer_server_ciphers on;
```

- 5.每一次生成https证书后有效期只有三个月，需要快过期时更新（剩余七天内可以重新生成）
```
# 替换ls.xxx.xyz为自己的域名
sudo ~/.acme.sh/acme.sh --renew -d ls.xxx.xyz --force --ecc
```

# 3.配置v2ray
## 1.安装v2ray

```
bash <(curl -L -s https://install.direct/go.sh)
```

## 2.v2ray配置文件

- 下载config_ws_tls.json
```
cd&&wget https://raw.githubusercontent.com/mack-a/v2ray-agent/master/config/config_ws_tls.json
```

- 配置文件的id可以自己生成一个新的，替换即可
```
/usr/bin/v2ray/v2ctl  uuid
```

## 3.启动v2ray
```
/usr/bin/v2ray/v2ray -config ./config_ws_tls.json&
```

# 4.客户端
## 1.MacOS
- 下载V2RayU[点我下载](https://github.com/yanue/V2rayU/releases/download/1.4.1/V2rayU.dmg)
- 下载后打开，服务器设置，修改address即可
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/v2rayU_服务器配置.png" width=400>

- pac设置，添加下面的链接
```
https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
```

- 选择使用Pac模式，即可
## 2.windows
- 下载v2rayN[点我下载](https://github.com/2dust/v2rayN/releases/download/2.44/v2rayN.zip)
- 使用方法 [点我查看](https://github.com/233boy/v2ray/wiki/V2RayN%E4%BD%BF%E7%94%A8%E6%95%99%E7%A8%8B)

<hr/>
<h3>到这里就配置完成，可以测试是否能上被q的网站</h3>
<hr/>

# 5.其余设置
## 1.开机自启
### 1.配置Nginx开机自启
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

### 2.配置v2ray_ws_tls开机自启
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
### 3.测试开机自启是否成功
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
# 6.异常处理
## 1.偶尔断流
- 修改cloudflare Firwall Rules->create a Firewall rule
- - 设置Field:URI path
- - 设置：value:/v2
- - Choose an action:Allow

# 7.开启Centos bbr拥塞控制算法[我的测试机是centos 8]
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
