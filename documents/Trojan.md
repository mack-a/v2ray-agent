- [1.特点](#1特点)
- [2.安装](#2安装)
  * [1.生成TLS证书【Let’s Encrypt】](#1生成tls证书lets-encrypt)
    + [主要步骤](#主要步骤)
  * [2.安装Trojan](#2安装Trojan)
    + [1.执行下方命令](#1执行下方命令)
    + [2.修改Trojan配置文件](#2修改Trojan配置文件)
    + [3.配置文件主要内容说明](#3配置文件主要内容说明)
    + [4.详细配置文件说明](#4.详细配置文件说明)
- [3.启动](#3启动)
- [4.配置与V2Ray并存【并保证网站伪装】【待完善】](#4配置与v2ray并存并保证网站伪装待完善)

# 1.特点
- 1.tls加密数据通过防火墙。
- 2.无法使用CloudFlare代理。
- 3.Trojan使用C++实现，较其他语言效率高。
- 4.客户端少，ios端表现不如V2Ray（Quantumult）。
- 5.需要自己维护证书。

# 2.安装
## 1.生成TLS证书【Let’s Encrypt】
### 主要步骤
- 1.配置DNS解析
- 2.安装Nginx
- 3.Let’s Encrypt生成证书
- 4.参考[此链接](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Full.md#1%E5%87%86%E5%A4%87%E5%B7%A5%E4%BD%9C)中【1.准备工作】和【2.vps配置Nginx、https】。

## 2.安装Trojan
### 1.执行下方命令
```
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
```

### 2.修改Trojan配置文件
- 1.文件路径
```
/usr/local/etc/trojan/config.json
```

- 2.修改证书和密钥
```
vi /usr/local/etc/trojan/config.json

# 找到下方两行 修改为自己的存放证书的路径
"cert": "/path/to/certificate.crt",
"key": "/path/to/private.key",

# 找到下方位置，有几个用户就要填写几个密码
"password":[
    "7f3a2df1-64e8-48bb-ebf8-3953ed699495",
    "b2cc18e3-e4b3-eff8-f24c-a4a4f80a9af9"
]
```

### 3.配置文件主要内容说明
- local_port:监听的端口号，默认443，如果443封禁了，可以更换其余端口。
- remote_addr和remote_port：非trojan协议时，将请求转发处理的地址和端口。默认80，80端口可以开放给Nginx来配置个人站点或者伪装其他网址，也可以配置搭配V2Ray，来实现一个VPS多种协议；
- password：密码。需要几个填写几个，可以使用v2ctl uuid生成，也可以随便填写，最后一行不可以有逗号。

### 4.详细配置文件说明
- [点此查看](https://trojan-gfw.github.io/trojan/config)

# 3.启动
- 1.开机自启
```
systemctl enable trojan
```

- 2.启动
```
systemctl start trojan
```

- 3.关闭
```
systemctl stop trojan
```

# 4.配置与V2Ray并存【并保证网站伪装】
- 1.需要配合CloudFlare
- 2.需要使用【方法1】配置V2Ray[点此查看](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Flexible.md)

## 1.思路
- 1.配置两个不同的二级域名
- 2.CloudFlare对V2Ray的二级域名开启Proxy【☁️】
- 3.SSL/TLS mode 修改为Fiexible

## 2.示例
### 1.CloudFlare SSL/TLS mode
<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_tls_Flexible.png' width=400>

### 2.CloudFlare DNS Trojan&V2Ray
- 1.blog2 指向Trojan的443
- 2.blog 则通过CloudFlare指向VPS的80
- 3.指向的ip是一样的，一个通过CloudFlare代理一个则不代理。

<img src='https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/CloudFlare Trojan V2Ray.png' width=400>

### 3.Nginx config
```
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

   server {
       	listen       80;
       	# 这里是你的域名
       	server_name  blog.xxx.xyz;
       	root         /usr/share/nginx/html;

       	location / {

       	}
   	    location ~ /.well-known {
        	allow all;
        }
        # 这里是V2Ray
        location /main {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:31290;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            # proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
   }
}

```
### 4.Trojan则不用修改
