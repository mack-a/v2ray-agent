# 任意门解锁netfix

> [参考文章](https://gist.github.com/phlinhng/c11c1268748874982fa6596fb0a4992a)

# 1.概述

目前解锁Netflix有三种方式，这里我们介绍的是下面的第二种

- 1.购买dns解锁服务
- 2.在主力机的基础中再购买Netflix解锁的机器
- 3.购买的vps自带解锁服务

# 2.准备工作

- 1.购买可以解锁Netflix的机器
- 2.使用本脚本搭建完毕两台机器，安装Netflix解锁机时不区分协议，随便安装一个协议即可

# 3.解锁步骤

- 1.需要分别设置两台vps的入站和出战，即**要解锁的vps**设置**出站**，**已经解锁的vps**设置**入站**
- 2.举例

下面有vpsA、vpsB两台vps。 vpsA为BWH GIA，不解锁Netflix，vpsB为解锁Netflix的vps。

这个时候我们需要两步操作

- 1.登录**vpsA**，使用脚本中的 **流媒体工具箱->任意门落地机解锁Netflix->设置出站**，ip为上面的**已经解锁Netflix的vpsB的ip**
- 2.登录**解锁的Netflix的vps**，使用脚本中的**流媒体工具箱->任意门落地机解锁Netflix->设置入站**，ip为上面的**vpsA的ip**

# 4.卸载

- 卸载不区分入站、出站，卸载即可。




