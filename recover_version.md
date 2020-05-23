# 前言
>重新整理下目前的教程以及未来要加入的内容，并给出确切TodoList。


# 1.V2Ray
## 1.CDN手动部署
- 极适用于被墙的VPS
### 1.Cloudflare+V2Ray+WebSocket+Nginx+Web伪装博客【建议使用该方法】
- 仅使用Cloudflare的证书
- 客户端->Cloudflare使用TLS+Vmess加密，Cloudflare->VPS仅使用Vmess，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Flexible.md)
- 不需要维护TLS证书
- 少一步解析证书的过程，速度理论上会快一些

### 2.Cloudflare+V2Ray+WebSocket+TLS+Nginx+Web伪装博客
- 需要TLS，一般使用let's encrypt生成，有效期为三个月。
- 客户端->Cloudflare使用Cloudflare TLS+Vmess加密，Cloudflare->VPS使用let's encrypt TLS+Vmess加密，[点击查看](https://github.com/mack-a/v2ray-agent/blob/master/Cloudflare_Full.md)

# 2.全自动化一键脚本、博客搭建【博客书写需要熟悉markdown语法】
- 2020-5-16 立项，预计完成时间2020-6-16

## [ ] 脚本编写
## [ ] 自动博客搭建【Hexo+Next】
- [ ] 1.博客编写
- [ ] 2.博客部署【githook、Jekins】

# 3.V2Ray配置文件生成
- 2020-5-16 立项，预计完成时间2020-6-20

# 4.k8s集群、Docker
- 2020-5-16 立项，预计完成时间****
- [ ] 私有仓库托管
- [ ] k8s集群管理
