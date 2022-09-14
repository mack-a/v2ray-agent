# v2ray-agent

> [Thanks for non-commercial open source development authorization by JetBrains](https://www.jetbrains.com/?from=v2ray-agent)

- [Cloudflare Optimization Solutions](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [Traffic Transit Tutorial](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [SSH Getting Started Tutorial](https://www.v2ray-agent.com/2020-12-16-ssh%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B)
- [TG Group](https://t.me/technologyshare)、[TG Channel](https://t.me/joinchat/VuYxsKnlIQp3VRw-)、[Blog](https://www.v2ray-agent.com/)
- Welcome Pull request

* * *

# Catalog

- [1.Installation Script](#1vlesstcptlsvlesswstlsvmesstcptlsvmesswstlstrojan-伪装博客-五合一共存脚本)
    * [Characteristics](#characteristics)
    * [architecture](#architecture)
    * [Line recommendation(China)](#line-recommendationchina)
    * [Combination recommendation](#combination-recommendation)
    * [Cautions](#cautions)
    * [Usage](#usage)

* * *

# 1.Eight-in-One Coexistence Script+Camouflage site

- [Cloudflare Introductory tutorial](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)

## Characteristics

- Support [Xray-core[XTLS]](https://github.com/XTLS/Xray-core) and [v2ray-core](https://github.com/v2fly/v2ray-core)
- Support VLESS/Trojan Forward Proxy [VLESS XTLS -> Trojan XTLS]、[Trojan XTLS -> VLESS XTLS]
- Support for reading configuration files from different cores to each other
- Support VLESS/VMess/trojan
- Support Debian, Ubuntu, and Centos. Support mainstream cpu architecture
- Support any combination of installation, multi-user management, adding multiple ports
- Support IPv6，[IPv6 Notes](https://github.com/mack-a/v2ray-agent/blob/master/documents/ipv6_help.md)
- [Support custom certificate installation](https://github.com/mack-a/v2ray-agent/blob/master/documents/install_tls.md)

## Supported installation types

- VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-direct
- VLESS+gRPC+TLS [Support CDN, IPv6, low latency]
- VLESS+WS+TLS [Support CDN, IPv6]
- Trojan+TCP+TLS [**Recommended**]
- Trojan+TCP+xtls-rprx-direct
- Trojan+gRPC+TLS [Support CDN, IPv6, low latency]
- VMess+WS+TLS [Support CDN, IPv6]

## Cautions

- **Modify Cloudflare->SSL/TLS->Overview->Full**
- **Cloudflare ---> A record resolution of clouds must be gray**
- **If you use CDN and direct connection at the same time, turn off cloud and use self-selected IP. More info in [Cloudflare Optimization Solutions](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)**
- **Use the pure system installation, if you have installed using other scripts, please re-build the system and then install**
- wget: command not found [**Here you need to manually install the wget yourself**]
  , If you have not used Linux，[Click to view](https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md)Installation Tutorial
- Non-root accounts are not supported
- **If you find Nginx-related problems, please uninstall the self-compiled nginx or re-build the system**
- **If you want to give feedback, please show detailed screenshots or in accordance with the template specifications. No screenshots or not in accordance with the specifications of the issue will be directly closed**
- **Not recommended for GCP users**
- **Centos and lower versions are not recommended, Centos6 and Ubuntu 16.x are no longer supported**
- **Oracle Cloud has an additional firewall that needs to be set manually**
- **Oracle Cloud only supports Ubuntu**
- **If you use gRPC to forward through cloudflare, you need to allow gRPC in cloudflare settings, path: cloudflare Network->gRPC**
- **gRPC is currently in beta and may not be compatible with the client you are using. Ignore it if you have any problems**
- **The issue about not starting when the script is upgraded from lower version, [Here is solution](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md#4%E4%BD%8E%E7%89%88%E6%9C%AC%E5%8D%87%E7%BA%A7%E9%AB%98%E7%89%88%E6%9C%AC%E5%90%8E%E6%97%A0%E6%B3%95%E5%90%AF%E5%8A%A8%E6%A0%B8%E5%BF%83)**

## Script Catalog

- v2ray-core 【**/etc/v2ray-agent/v2ray**】
- Xray-core 【**/etc/v2ray-agent/xray**】
- Trojan 【**/etc/v2ray-agent/trojan**】
- TLS 【**/etc/v2ray-agent/tls**】
- Nginx Configuration file 【**/etc/nginx/conf.d/alone.conf**】、Nginx fake site directory 【**/usr/share/nginx/html**】

## Usage

- Support shortcut start, after installation, shell input [**vasma**] to open the script, script execution path [**/etc/v2ray-agent/install.sh**]

- Latest Version
```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/install_en.sh" && chmod 700 /root/install_en.sh && mv /root/install_en.sh /root/install.sh && /root/install.sh
```

- Example diagram

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# License

[GPL-3.0](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
