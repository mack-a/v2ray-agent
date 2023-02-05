#v2ray-agent [GOOGLE TRANSLATED]

> [Thanks to JetBrains for the non-commercial open source software development license](https://www.jetbrains.com/?from=v2ray-agent)

> [Thanks for non-commercial open source development authorization by JetBrains](https://www.jetbrains.com/?from=v2ray-agent)

> [English Version](https://github.com/mack-a/v2ray-agent/blob/master/documents/en/README_EN.md)

- [Cloudflare Optimization Solution](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [Traffic Relay](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [Manual self-built tutorial](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_install_manual.md)
- [ssh entry tutorial](https://www.v2ray-agent.com/2020-12-16-ssh%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B )

- [TG group](https://t.me/technologyshare), [TG channel - update notice](https://t.me/v2rayAgentChannel), [blog address](https://www.v2ray-agent .com/)
- **Please support with a ⭐**

* * *

# Table of contents

- [1. Script installation](#1vlesstcptlsvlesswstlsvmesstcptlsvmesswstlstrojan-fake site-five-in-one coexistence script)
     - [property](#property)
     - [Notes] (#Notes)
     - [install script] (#install script)

* * *

# 1. Eight-in-one coexistence script + camouflage site

- [Cloudflare Getting Started Tutorial](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)

## Features
- Supports [Xray-core[XTLS]](https://github.com/XTLS/Xray-core), [v2ray-core](https://github.com/v2fly/v2ray-core), [hysteria] (https://github.com/apernet/hysteria)
- Support configuration files between different cores to read each other
- Support VLESS/VMess/Trojan/hysteria protocols
- Support Debian, Ubuntu, Centos systems, support mainstream cpu architecture.
- Support any combination of installation, support multi-user management, support DNS streaming media unlocking, support adding multiple ports, [support any door forwarding traffic, can be used to unlock Netflix, Google human-machine verification, etc.](https://github.com/mack -a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md)
- Support to keep tls certificate after uninstall
- Support IPv6, [IPv6 Considerations](https://github.com/mack-a/v2ray-agent/blob/master/documents/ipv6_help.md)
- Support WARP distribution, IPv6 distribution, any door distribution
- Support BT download management, log management, domain name blacklist management, core management, camouflage site management, routing rule file management
- [Support custom certificate installation](https://github.com/mack-a/v2ray-agent/blob/master/documents/install_tls.md)

## Supported installation types

-VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-vision [recommended]
- VLESS+gRPC+TLS [support CDN, IPv6, low latency]
- VLESS+WS+TLS [Support CDN, IPv6]
-Trojan+TCP+TLS
- Trojan+gRPC+TLS【Support CDN, IPv6, low latency】
- VMess+WS+TLS【Support CDN, IPv6】
- Hysteria【Recommendation】

## Route recommendation

- [CN2 GIA](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#1cn2-gia)
- [AS9929](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#2%E8%81%94%E9%80%9A-as9929a%E7%BD %91)
- [AS4837](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#3%E8%81%94%E9%80%9A-as4837%E6%99 %AE%E9%80%9A%E6%B0%91%E7%94%A8%E7%BD%91)
- [Softbank Japan](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#4%E8%81%94%E9%80%9A-%E6%97 %A5%E6%9C%AC%E8%BD%AF%E9%93%B6)
- [CMI](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#5cmi)
- Transit + cloudflare + landing machine [Kola Global]

## Precautions

- **Modify Cloudflare->SSL/TLS->Overview->Full**
- **Cloudflare ---> The cloud analyzed by the A record must be gray [if it is not gray, it will affect the automatic renewal of the certificate for the scheduled task]**
- **If you use CDN and use direct connection at the same time, close the cloud + self-selected IP, and refer to the [Cloudflare optimization plan] above for the self-selected IP (https://github.com/mack-a/v2ray-agent/blob/master/documents /optimize_V2Ray.md)**
- **Install with a clean system, if you have installed with other scripts and cannot modify the error yourself, please reinstall the system and try to install again**
- wget: command not found [**Here you need to manually install wget**]
   , if you have not used Linux, [click to view] (https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md) installation tutorial
- Does not support non-root accounts
- **If you find Nginx-related problems, please uninstall the self-compiled nginx or reinstall the system**
- **In order to save time, please bring detailed screenshots or follow the template specifications for feedback. Issues without screenshots or not following the specifications will be closed directly**
- **Not recommended for GCP users**
- **Centos and lower version systems are not recommended. If Centos installation fails, please switch to Debian10 and try again. The script no longer supports Centos6, Ubuntu 16.x**
- **[If you don’t understand the use, please check the script usage guide first](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md)**
- **Oracle Cloud has an additional firewall that needs to be set manually**
- **Oracle Cloud only supports Ubuntu**
- **If you use gRPC to forward through cloudflare, you need to allow gRPC in cloudflare, path: cloudflare Network->gRPC**
- **gRPC is currently in beta and may not be compatible with the client you are using, please ignore if it cannot be used**

## [Script usage guide](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md), [Script directory](https://github.com/mack- a/v2ray-agent/blob/master/documents/how_to_use.md#5 script directory)

## donate

[You can use my AFF to purchase VPS donation-blog](https://www.v2ray-agent.com/%E6%82%A8%E5%8F%AF%E4%BB%A5%E9%80% 9A%E8%BF%87%E6%88%91%E7%9A%84AFF%E8%B4%AD%E4%B9%B0vps%E6%8D%90%E8%B5%A0)

[You can use my AFF to purchase VPS donation-Github](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md)

[Support donating to me via virtual currency](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation.md)

## Install script

-Shortcut startup is supported. After the installation is complete, enter [**vasma**] in the shell to open the script. The script execution path is [**/etc/v2ray-agent/install.sh**]

- Latest Version [Recommended]

```
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/ExtremeDot/v2ray-agent/patch-1/IRAN-install.sh" && chmod 700 /root/IRAN-install.sh && bash / root/IRAN-install.sh
```


# sample graph

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# license

[AGPL-3.0](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
