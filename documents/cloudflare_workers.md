- [注意事项](#注意事项)
- [步骤](#步骤)
  * [1.创建Workers自定义域名](#1创建Workers自定义域名)
  * [2.绑定域名](#2绑定域名)
  * [3.创建Workers](#3创建Workers)
  * [4.使用](#4使用)
  
# 注意事项
- Wokers是Cloudflare基于CDN的无服务器应用程序。
- ~~想使用Wokers，域名必须必须托管在Cloudflare~~[错误]
- 每天10万条请求
- 保证在没有使用Workers的情况可以正常使用服务【CDN+WebSocket+TLS or WebSocket+TLS】
 
# 步骤
## 1.创建Workers自定义域名
- 域名的前缀可以自定义
- Plan选择free即可
- 会验证邮箱
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_01.png" width=400>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_02.png" width=400>

## ~~2.绑定域名~~[这一步可以不用看，直接看下面的即可]
- 1.添加域名
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_03.png" width=400>

- 2.修改域名注册商的Nameserver
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_04.png" width=400>

- 3.创建域名解析，这里域名可以直接用能正常访问的服务或者创建新的，如果创建新的并且证书是通配符证书则用新旧域名都无影响，如果不是通配符需要重新生成证书以及配置相关的Nginx服务

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_06.png" width=400>

## 3.创建Workers
- 1.填写Workers的Script为下方内容【hostname填写科学上网的域名，比如 workerproxy.v2ray-agent.com 】
```
addEventListener(
  "fetch",event => {
     let url=new URL(event.request.url);
     url.hostname="这里要修改为自己的";
     let request=new Request(url,event.request);
     event. respondWith(
       fetch(request)
     )
  }
)
```
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_05.png" width=400>
<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/Workers/Workers_07.png" width=400>

## 4.使用
- 1.客户端只需要将address部分修改为上图第二个红框位置的内容即可