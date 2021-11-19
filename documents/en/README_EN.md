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

# 1.Seven-in-One Coexistence Script+Camouflage site

- [Cloudflare Introductory tutorial](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)

## Characteristics

- Support [Xray-core[XTLS]](https://github.com/XTLS/Xray-core)、v2ray-core [XTLS]、v2ray-core
- Support for reading configuration files from different cores to each other
- Support VLESS/VMess/trojan/trojan-go[ws]
- Support Debian、Ubuntu、Centos,Support mainstream cpu architecture。**Centos and lower versions of systems are not recommended,Centos6 is no longer supported after 2.3.x**
- Support for personalized installation
- Install and reinstall any combination without uninstalling. No extra files left when uninstalling the script
- Support IPv6，[IPv6 Notes](https://github.com/mack-a/v2ray-agent/blob/master/documents/IPv6_help.md)
- Support for human verification using IPv6 to exclude Google,**You need to apply for IPv6 tunnel by yourself, it is not recommended to use the IPv6 that comes with the vps**
- [Support custom certificate installation](https://github.com/mack-a/v2ray-agent/blob/master/documents/install_tls.md)

## Architecture

- VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-direct【**Recommended**】
- VLESS+WS+TLS【Support CDN、IPv6】
- VMess+TCP+TLS
- VMess+WS+TLS【Support CDN、IPv6】
- Trojan【**Recommended**】
- Trojan-Go+WS【Support CDN、不支持IPv6】

## Line recommendation(China)

- 1.GIA
- 2.Shanghai CN2+HK
- 3.Shanghai Unicom+Taiwan TFN
- 4.Shanghai Unicom+Vultr Tokyo
- 5.Guangdong Mobile/Zhuhai Mobile+HKIX/CMI/NTT
- 6.Suzhou->Japan IPLC+Japan/US
- 7.Dongguan->HongKong IPLC+HK
- 8.Guangdong Mobile/Shanghai CN2+Cloudflare+Global
- 9.Guangdong Mobile/CN2/South China Unicom+HK AZ+Global
- 10.North China Unicom+Siberia、Burley ttk/RT
- 11.CN2+HE
- 12.China Telecom+Far EasTone Taiwan

## Combination recommendation

- Transit/gia ---> VLESS+TCP+TLS/XTLS、Trojan【Recommended Use XTLS->xtls-rprx-direct】
- China Mobile Broadband ---> VMESS+WS+TLS/Trojan-Go+WS + Cloudflare
- Trojan recommends turning on Mux【**Multiplexing**】，Client-side on only, server-side adaptive
- VMess/VLESS can also open Mux, the effect needs to be tried by yourself, XTLS does not support Mux. only the client needs to open, the server side adaptive.

## Cautions

- Modify Cloudflare->SSL/TLS->Overview->Full
- Cloudflare ---> A record resolution of clouds must be gray
- **Use the pure system installation, if you have installed using other scripts, please re-build the system and then install**
- wget: command not found [**Here you need to manually install the wget yourself**]
  ，If you have not used Linux，[Click to view](https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md)Installation Tutorial
- Non-root accounts are not supported
- **The version number upgrade in the middle means that it may not be compatible with the previously installed content, so please upgrade carefully if you are not chasing new users or must upgrade the
  version. ** For example, 2.2.\*, not compatible with 2.1.\*
- **If you find Nginx-related problems, please uninstall the self-compiled nginx or re-build the system**
- **In order to save time, feedback please bring detailed screenshots or in accordance with the template specifications, no screenshots or not in accordance with the specifications of the issue will
  be directly closed**
- **Not recommended for GCP users**
- **Centos and lower versions are not recommended, Centos6 is no longer supported after 2.3.x**

## Script Catalog

- v2ray-core 【**/etc/v2ray-agent/v2ray**】
- Xray-core 【**/etc/v2ray-agent/xray**】
- Trojan 【**/etc/v2ray-agent/trojan**】
- TLS 【**/etc/v2ray-agent/tls**】
- Nginx Configuration file 【**/etc/nginx/conf.d/alone.conf**】、Nginx fake site directory 【**/usr/share/nginx/html**】

## [Scripting Common Commands](https://github.com/mack-a/v2ray-agent/blob/master/documents/common_commands.md)

## [Common script errors handling](https://github.com/mack-a/v2ray-agent/blob/master/documents/shell_error.md)

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
