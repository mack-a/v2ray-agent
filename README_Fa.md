# v2ray-agent

> [از مجوز توسعه منبع باز غیر تجاری توسط JetBrains سپاسگزاریم](https://www.jetbrains.com/?from=v2ray-agent)

> [از مجوز توسعه منبع باز غیر تجاری توسط JetBrains سپاسگزاریم]( https://www.jetbrains.com/?from=v2ray-agent)

> [English Version](https://github.com/mack-a/v2ray-agent/blob/master/documents/en/README_EN.md)

- [راه حل بهینه سازی Cloudflare](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)
- [رله ترافیک](https://github.com/mack-a/v2ray-agent/blob/master/documents/traffic_relay.md)
- [آموزش ساخت دستی](https://github.com/mack-a/v2ray-agent/blob/master/documents/Cloudflare_install_manual.md)
- [آموزش مقدماتی ssh](https://www.v2ray-agent.com/2020-12-16-ssh%E5%85%A5%E9%97%A8%E6%95%99%E7%A8%8B)

- [گروه TG](https://t.me/technologyshare), [TG channel-update notification](https://t.me/v2rayAgentChannel), [blog address](https://www.v2ray-agent.com/)
- **لطفا با دادن یک ⭐ حمایت کنید**

* * * 

# کاتالوگ

- [1.اسکریپت‌نصب](#1.اسکریپت_هشت_در_یک_همزیستی_+_سایت_ساختگی)
  - [امکانات](#امکانات)
  - [اقدام‌احتیاطی](#اقدام_احتیاطی)
  - [اسکریپت‌نصب](#اسکریپت_نصب)

* * * 

# 1.اسکریپت_هشت_در_یک_همزیستی_+_سایت_ساختگی

- [آموزش شروع به کار با Cloudflare](https://github.com/mack-a/v2ray-agent/blob/master/documents/cloudflare_init.md)

## امکانات
- پشتیبانی از [Xray-core[XTLS]](https ://github.com/XTLS/Xray-core), [v2ray-core](https://github.com/v2fly/v2ray-core)
- پشتیبانی از پروتکل VLESS/VMess/trojan
- از VLESS/Trojan prepending پشتیبانی می کند [VLESS XTLS -> Trojan XTLS], [Trojan XTLS -> VLESS XTLS]
- پشتیبانی از خواندن متقابل فایل های پیکربندی بین هسته های مختلف
- Trojan+TCP+xtls-rprx-direct
- از سیستم‌های Debian، Ubuntu، Centos و معماری‌های اصلی CPU پشتیبانی کنید.
- پشتیبانی از هر ترکیبی از نصب، پشتیبانی از مدیریت چند کاربره، پشتیبانی از باز کردن قفل رسانه جریان DNS، پشتیبانی از افزودن چندین پورت، [پشتیبانی از هر دری برای باز کردن قفل Netflix](https://github.com/mack-a/v2ray-agent/blob/master/documents/netflix/dokodemo-unblock_netflix.md)
- پشتیبانی از نگهداری گواهی tls پس از حذف
- پشتیبانی از IPv6، [یادداشت IPv6](https://github.com/mack-a/v2ray-agent/blob/master/documents/ipv6_help.md)
- پشتیبانی از WARP offload، IPv6 offload
- پشتیبانی از مدیریت دانلود BT، مدیریت لاگ، مدیریت لیست سیاه نام دامنه، مدیریت هسته، مدیریت سایت استتار
- [پشتیبانی از نصب گواهی سفارشی](https://github.com/mack-a/v2ray-agent/blob/master/documents/install_tls.md)

## انواع نصب پشتیبانی شده

- VLESS+TCP+TLS
- VLESS+TCP+xtls-rprx-direct
- VLESS+gRPC+TLS [support CDN, IPv6, delay Low]
- VLESS+WS+TLS [support CDN, IPv6]
- Trojan+TCP+TLS [**توصیه شده**]
- Trojan+gRPC+TLS [support CDN, IPv6, low latency]
- VMess+WS+TLS [support CDN, IPv6]

## توصیه مسیر

- [CN2 GIA](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#1cn2-gia)
- Shanghai CN2+HK
- [AS9929]( https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#2%E8%81%94%E9%80%9A-as9929a%E7%BD%91)
- [AS4837](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#3%E8%81%94%E9%80%9A-as4837%E6%99%AE%E9%80%9A%E6%B0%91%E7%94%A8%E7%BD%91)
- [Unicom Japan Softbank](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md#4%E8%81%94%E9%80%9A-%E6%97%A5%E6%9C%AC%E8%BD%AF%E9%93%B6)
- Unicom+ Taiwan TFN
- China Unicom+NTT
- Guangzhou Mobile/Zhushift+HKIX/CMI/NTT
- Guangzhou Mobile/CN2+Cloudflare+ Global
- Guangzhou Mobile/CN2/South Union+Hong Kong AZ+Global
- Transit+cloudflare+Landing Machine【Kela Global】

## اقدام_احتیاطی

- **Cloudflare->SSL/TLS->Overview->Full را تغییر دهید**
- **Cloudflare ---> ابرهای تجزیه شده توسط یک رکورد باید خاکستری باشد [اگر خاکستری نباشد، بر گواهی تمدید خودکار وظایف برنامه ریزی شده تأثیر می گذارد]**
- **اگر از CDN و اتصال مستقیم به طور همزمان استفاده می کنید، Yunduo + IP خود انتخابی را خاموش کنید، به قسمت بالا مراجعه کنید [طرح بهینه سازی Cloudflare](https://github.com/mack-a/v2ray-agent/blob/master/documents/optimize_V2Ray.md)**
- **برای نصب از سیستم خالص استفاده کنید، اگر آن را با اسکریپت های دیگر نصب کرده اید و خودتان نمی توانید خطا را اصلاح کنید، لطفاً سیستم را دوباره نصب کنید و دوباره سعی کنید نصب کنید.**
- wget: command not found [**Here you need to do it manually Install wget**]
  , اگر از لینوکس استفاده نکرده اید، [برای مشاهده کلیک کنید](https://github.com/mack-a/v2ray-agent/tree/master/documents/install_tools.md) آموزش نصب
- از حساب غیر روت پشتیبانی نمی کند
- **اگر مشکلات مربوط به Nginx را پیدا کردید، لطفا nginx خودکامپایل شده را حذف نصب کنید یا سیستم را دوباره نصب کنید.**
- **به منظور صرفه جویی در زمان، لطفاً اسکرین شات های دقیق بیاورید یا مشخصات الگو را برای بازخورد دنبال کنید، هیچ اسکرین شات یا مشکلی که از مشخصات پیروی نمی کند مستقیما بسته می شود.**
- **برای کاربران GCP توصیه نمی شود**
- **Oracle Cloud یک فایروال اضافی دارد که باید به صورت دستی تنظیم شود**
- **Centos و نسخه‌های پایین‌تر سیستم توصیه نمی‌شوند، اگر نصب Centos با شکست مواجه شد، لطفاً به Debian10 بروید و دوباره امتحان کنید، اسکریپت دیگر از Centos6، Ubuntu 16.x پشتیبانی نمی‌کند.**
- **[اگر کاربرد را درک نمی کنید، لطفاً ابتدا راهنمای استفاده از اسکریپت را بررسی کنید](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md)**
- ** Oracle Cloud فقط از اوبونتو پشتیبانی می کند**
- **اگر از gRPC برای ارسال از طریق cloudflare استفاده می کنید، باید gRPC را در تنظیمات cloudflare مجاز کنید، مسیر: cloudflare Network->gRPC**
- **gRPC در حال حاضر در مرحله بتا است و ممکن است برای کلاینتی که از آن استفاده می‌کنید کار نکند، اگر نمی‌توانید از آن استفاده کنید، لطفاً نادیده بگیرید **
- ** مشکل این است که اسکریپت نسخه پایین تر نمی تواند هنگام ارتقاء نسخه بالاتر شروع شود، [please click this link to view the solution](https://github.com/mack-a/v2ray-agent/blob/master/documents/how_to_use.md#4%E4%BD%8E%E7%89%88%E6%9C%AC%E5%8D%87%E7%BA%A7%E9%AB%98%E7%89%88%E6%9C%AC%E5%90%8E%E6%97%A0%E6%B3%95%E5%90%AF%E5%8A%A8%E6%A0%B8%E5%BF%83)**

## کمک مالی

[You can use my AFF to buy VPS donation-blog](https://www.v2ray-agent.com/%E6%82%A8%E5%8F%AF%E4%BB%A5%E9%80%9A%E8%BF%87%E6%88%91%E7%9A%84AFF%E8%B4%AD%E4%B9%B0vps%E6%8D%90%E8%B5%A0)

[You can use my AFF to buy VPS donations - Github](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation_aff.md)

[Support donations to me via virtual currency](https://github.com/mack-a/v2ray-agent/blob/master/documents/donation.md)

## اسکریپت_نصب

- از راه اندازی میانبر پشتیبانی می کند، پس از نصب، [**vasma**] را در پوسته وارد کنید، می توانید اسکریپت، مسیر اجرای اسکریپت را باز کنید [**/etc/v2ray-agent/install.sh**]

- آخرین نسخه [توصیه شده]

``` 
wget -P/root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/shell/install_en.sh" && mv /root/install_en.sh /root/install.sh && chmod 700 /root/install.sh &&/root/install.sh
``` 


# تصویر نمونه

<img src="https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/install/install.jpg" width=700>

# licence

[AGPL-3.0](https://github.com/mack-a/v2ray-agent/blob/master/LICENSE)

## Stargazers over time

[![Stargazers over time](https://starchart.cc/mack-a/v2ray-agent.svg)](https://starchart.cc/mack-a/v2ray-agent)
