# 使用现有的证书进行脚本安装
## 1.创建目录
```
mkdir -p /etc/v2ray-agent/tls
```
## 2.将证书放到指定目录并修改名称
>下方的domain为要安装的域名
- 1.移动证书和私钥到/etc/v2ray-agent/tls下
- 2.修改文件名称
```
xxx.key --> domain.key
xxx.crt or xxx.pem or xxx.cer --> domain.crt
```