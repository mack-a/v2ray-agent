# 1.打开Nginx配置文件

```
vim /etc/nginx/conf.d/alone.conf
```

# 2.添加配置

- 如需配置HTTP1.1，找到31300端口所在的server【文件最后，非return 403那条】
- 如需配置HTTP2.0，找到31302端口所在的server

> 下方使用配置HTTP1.1反向代理作为示例

```
# 如果要添加到根路由，则添加到localtion /下面
location / {
	add_header Strict-Transport-Security "max-age=15552000; preload" always;
	proxy_pass http://127.0.0.1:3003/;
}

# 如果只需要添加额外的路径，则额外写一个location，路径可自定义
location /test {
	proxy_pass http://127.0.0.1:3003/;
}

# 完整配置，HTTP2.0则同理，写入到31302端口所在的server即可
server {
	listen 127.0.0.1:31300;
	server_name xx;
	root /usr/share/nginx/html;
	location /s/ {
		add_header Content-Type text/plain;
		alias /etc/v2ray-agent/subscribe/;
	}
	location / {
		add_header Strict-Transport-Security "max-age=15552000; preload" always;
		proxy_pass http://127.0.0.1:3003/;
	}
    	location /test {
		proxy_pass http://127.0.0.1:3003/;
	}
}
```
