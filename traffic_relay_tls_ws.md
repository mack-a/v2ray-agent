- [1.准备工作](#1准备工作)
- [2.购买流量转发服务](#2购买流量转发服务)
- [3.配置流量转发服务](#3配置流量转发服务)
  * [1.配置idc.wiki流量转发](#1配置idcwiki流量转发)
  * [2.配置&修改DNS解析](#2配置修改dns解析这里示例为cloudflare)
- [4.修改客户端](#4修改客户端)
- [5节点测试](#5节点测试)
  * [1.联通](#1联通暂无)
  * [2.移动](#2移动)
  * [2.电信](#3电信暂无)

# 1.准备工作
- 1.需要一台没被墙的VPS（IPLC理论上是可以转发流量给被墙的VPS，目前手中没有被墙的VPS，无法进行测试）。
- 2.需要域名以及设置DNS解析，建议使用CloudFlare，其余的dns解析也可以。这里转发的是tls+ws流量，如果只是转发tcp vmess流量可以不用域名，但是vps会有被墙的风险，这里不推荐最基础tcp+vmess【如果有需要可以提issues】。
- 3.需要生成HTTPS证书，推荐使用通配符证书【通配符证书稍后完善】。
- 4.上面三个步骤参考 [点此链接查看](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Full.md)
- 5.必须保证在不用流量转发服务的情况可以使用tls+ws科学上网。
- 6.购买流量转发服务[点击购买](https://idc.wiki)

# 2.购买流量转发服务
- 1.注册-->[idc.wiki](https://idc.wiki)
- 2.注册完成后，服务-->购买新服务-->左侧显示菜单-->左侧列表最下面【流量转发服务】【建议购买150的服务，包含IPLC线路】

# 3.配置流量转发服务
## 1.配置idc.wiki流量转发
- 1.服务-->我的产品和服务-->管理产品-->添加普通转发&添加IPLC转发【普通和IPLC设置方式一样】
- 2.配置转发规则，这里只有一个点需要注意下一下【需转发地址，填写自己vps的ip以及https+ws的端口。】
```
# 示例
173.82.112.30:443
```
- 3.协议为TCP

## 2.配置&修改DNS解析【这里示例为CloudFlare】
- 1.idc.wiki 示例图
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/idcwiki_traffic.png" width=700>

- 2.修改域名dns解析到中转服务ip
```
# 1.name是你的二级域名的blog部分【blog.example.com】
# 2.content则是上述示例图转发部分的ip
```
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/cloudflare_idcwiki.png" width=700>

# 4.修改客户端
- 修改客户端端口部分【端口修改为中转IP的端口，例如上述的12187】
- 其余客户端类似，在保证ws+tls正常使用的情况下配置流量转发服务，客户端只需要修改为流量转发IP的端口即可。
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Quantumult_Setting.png" width=400>

# 5.节点测试
- 下列测试结果仅供参考
## 1.联通

节点|台湾GCP|洛杉矶
-|-|-
苏日IPLC ws_tls|延迟50ms-120ms，回源500ms-800ms|延迟100ms-200ms,回源1000ms-1500ms
徐州联通 ws_tls|延迟10ms-50ms，回源1000ms-1500ms|延迟10ms-50ms，回源1000ms-1500ms
上海电信 ws_tls|延迟1000ms+，回源2000ms+|延迟1000ms+，回源2000ms+
泉州CN2 ws_tls|延迟50ms-150ms，回源500ms-1000ms|延迟200ms+,回源1000ms+
绍兴双线[电信-联通出口] ws_tls|延迟200ms+,回源稳定1400ms左右|延迟30ms-40ms,回源3000ms+
绍兴双线[联通-联通出口] ws_tls|延迟200ms+,回源稳定1400ms左右|延迟30ms-40ms,回源2000ms+
常州三线[电信-联通出口] ws_tls|延迟200ms+,回源稳定1450ms左右|延迟200ms+,回源稳定2000ms+
常州三线[联通-联通出口] ws_tls|延迟200ms+,回源稳定1450ms左右|延迟200ms+,回源稳定2000ms+
常州三线[移动-联通出口] ws_tls|延迟200ms+,回源稳定1450ms左右|延迟200ms+,回源稳定2000ms+
绍兴双线[电信-电信出口] ws_tls|错误|错误
绍兴双线[联通-电信出口] ws_tls|延迟100ms以内，回源500ms-1000ms|延迟30ms-40ms,回源3000ms+

## 2.移动

节点|台湾GCP|洛杉矶
-|-|-
莞港IPLC ws_tls|延迟50ms-100ms，回源300ms-500ms|延迟50ms-100ms,回源800ms-1500ms
苏日IPLC ws_tls|延迟50ms-120ms，回源500ms-800ms|延迟100ms-200ms,回源1000ms-1500ms
莞港IPLC tcp_vmess|延迟50ms-100ms，回源100ms-200ms|暂无
苏日IPLC tcp_vmess|暂无|延迟100ms-200ms,回源400ms-500ms
上海电信 ws_tls|延迟50ms-100ms，会源500ms-700ms|延迟100ms-200ms，回源2000ms+
泉州CN2 ws_tls|延迟50ms-120ms，回源500ms-800ms|延迟100ms-200ms,回源1000ms-1500ms

## 3.电信【暂无】

