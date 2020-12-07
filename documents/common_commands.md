# 启动脚本
```
vasma
```

# 服务管理
## Xray-core、v2ray-core、trojan-go
- 重启
```
# xray
systemctl restart xray

# v2ray
systemctl restart v2ray

# trojan-go
systemctl restart trojan-go
```

- 启动
````
# xray
systemctl start xray

# v2ray
systemctl start v2ray

# trojan-go
systemctl start trojan-go
````

- 关闭
```
# xray
systemctl stop xray

# v2ray
systemctl stop v2ray

# trojan-go
systemctl stop trojan-go
```

## nginx
- 重启
```
nginx -s reload
```

- 启动
````
nginx
````

- 关闭
```
nginx -s stop
```