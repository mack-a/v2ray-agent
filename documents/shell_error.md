# 脚本常见错误处理
- 1.本脚本不支持ipv6，不兼容德鸡
- 2.输入域名后卡住
```
# 请手动打开icmp
```

- 3.下载脚本失败
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/shell_error_01.jpg" width=700>

>需要手动更改dns
```
# 文件位置
/etc/resolv.conf

# 文件内容
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
```

- 4.生成证书失败
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/shell_error_01.jpg" width=700>
>请更换Debian或者Ubuntu，或者拿着vps来私聊作者。