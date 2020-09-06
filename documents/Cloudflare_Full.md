# 目录
- [技能点列表](#技能点列表)
- [一键脚本](#一键脚本)
  * [1.自动模式](#1自动模式)
  * [2.手动模式](#2手动模式)
- [1.准备工作](#1准备工作)
  * [1.注册cloudflare](#1注册cloudflare)
  * [2.注册godaddy并购买域名](#2注册godaddy并购买域名)
  * [3.修改godaddy域名的DNS解析](#3修改godaddy域名的dns解析)
    + [1.登录cloudflare，添加域名](#1登录cloudflare添加域名)
    + [2.选择套餐](#2选择套餐)
    + [3.根据提示修改godaddy的dns解析](#3根据提示修改godaddy的dns解析)
  * [4.增加cloudflare域名解析](#4增加cloudflare域名解析)
  * [5.修改godaddy SSL/TLS](#5修改godaddy-ssltls)
- [2.vps配置Nginx、https](#2vps配置nginxhttps)
  * [1.安装Nginx](#1安装Nginx)
  * [2.nginx配置文件](#2nginx配置文件)
  * [3.生成https](#3生成https)
- [3.配置v2ray](#3配置v2ray)
  * [1.安装v2ray](#1安装v2ray)
  * [2.v2ray配置文件](#v2ray配置文件)
  * [3.启动v2ray](#3启动v2ray)
- [4.客户端](#4客户端)
  * [1.MacOS](#1macos)
  * [2.windows](#2windows)

# 1.准备工作
## 1.注册[cloudflare](cloudflare.com)
## 2.注册[godaddy](https://www.godaddy.com/)并购买域名或者使用免费域名[freenom](https://freenom.com/)
- 这里使用godaddy作为示例
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

# listen 443 ssl;
# ssl_certificate /etc/nginx/ls.xx.xyz.crt;
# ssl_certificate_key /etc/nginx/ls.xx.xyz.key;
# server_name ls.xx.xyz
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

- pac设置，添加下面的链接并选择使用Pac模式，即可
```
https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt
```

## 2.windows
- 下载v2rayN[点我下载](https://github.com/2dust/v2rayN/releases/download/2.44/v2rayN.zip)
- 使用方法 [点我查看](https://github.com/233boy/v2ray/wiki/V2RayN%E4%BD%BF%E7%94%A8%E6%95%99%E7%A8%8B)

## 3.Android
- [v2rayNG](https://github.com/2dust/v2rayNG/releases)

## 4.ios【需要自行购买或者使用共享账号安装】
- Quantumult【推荐使用】
- Shadowrocket
