# 1.手动自建教程
## 1.V2Ray
### 方法1(Flexible)【建议使用该方法】
- 只使用CloudFlare的证书
- 客户端->CloudFlare使用TLS+vmess加密，CloudFlare->VPS只使用vmess，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_Flexible.md)
- 不需要自己维护自己的https证书
- 少一步解析证书的过程，速度理论上会快一点

### 方法2(Full)
- 需要自己生成https证书，并自己维护，一般使用let's encrypt生成有效期为三个月。
- 客户端->CloudFlare使用CLoudFlare TLS+vmess加密，CloudFlare->VPS使用let's encrypt TLS+vmess加密，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_Full.md)
- 与方法1不同的是，CloudFlare和VPS通讯时也会使用TLS加密。两个方法安全方面区别不是很大。

### 方法3(Workers)
- [点击查看](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_workers.md)