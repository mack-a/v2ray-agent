# 注意事项
- ipv6在本地环境只支持ipv4的情况下，只可以使用Cloudflare【Trojan-Go ws、VLESS+TLS+WS、VMess+TLS+WS】
- ipv6可以结合此文档，使用自选ip实现更优的网络体验，[Cloudflare 优化方案](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- ipv6 vps需设置NAT64来下载脚本以及脚本中需要下载文件的问题

# NAT64设置方法
```
echo -e "nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6" > /etc/resolv.conf
```

# NAT64公益列表
```
2a01:4f9:c010:3f02::1
2001:67c:2b0::4
2001:67c:2b0::6
2a09:11c0:f1:bbf0::70
2a01:4f8:c2c:123f::1
2001:67c:27e4:15::6411
2001:67c:27e4::64
2001:67c:27e4:15::64
2001:67c:27e4::60
2a00:1098:2b::1
2a03:7900:2:0:31:3:104:161
2a00:1098:2c::1
2a09:11c0:100::53
```