- [1.CentOS7、8 配置及使用firewall](#1centos78-配置及使用firewall)
  * [1.systemctl是centos7的服务管理工具中主要的工具它融合之前service和chkconfig的功能于一体](#1systemctl是centos7的服务管理工具中主要的工具它融合之前service和chkconfig的功能于一体)
  * [2.firewalld的基本使用](2firewalld的基本使用)
  * [3.配置firewalld-cmd](3配置firewalld-cmd)

# 1.CentOS7、8 配置及使用firewall
## 1.systemctl是CentOS7的服务管理工具中主要的工具，它融合之前service和chkconfig的功能于一体。
- 启动一个服务
```
systemctl start firewalld.service
```
- 关闭一个服务
```
systemctl stop firewalld.service
```
- 重启一个服务
```
systemctl restart firewalld.service
```
- 显示一个服务的状态
```
systemctl status firewalld.service
```
- 在开机时启用一个服务
```
systemctl enable firewalld.service
```
- 在开机时禁用一个服务
```
systemctl disable firewalld.service
```
- 查看服务是否开机启动
```
systemctl is-enabled firewalld.service
```
- 查看已启动的服务列表
```
systemctl list-unit-files|grep enabled
```
- 查看启动失败的服务列表
```
systemctl --failed
```

## 2.firewalld的基本使用
- 启动
```
systemctl start firewalld
```
- 查看状态
```
systemctl status firewalld
```
- 停止
```
systemctl disable firewalld
```
- 禁用
```
systemctl stop firewalld
```

### 3.配置firewalld-cmd
- 查看版本
```
firewall-cmd --version
```
- 查看帮助
```
firewall-cmd --help
```
- 显示状态
```
firewall-cmd --state
```
- 查看所有打开的端口
```
firewall-cmd --zone=public --list-ports
```
- 更新防火墙规则
```
firewall-cmd --reload
```
- 查看区域信息
```
firewall-cmd --get-active-zones
```
- 查看指定接口所属区域
```
firewall-cmd --get-zone-of-interface=eth0
```
- 拒绝所有包
```
firewall-cmd --panic-on
```
- 取消拒绝状态
```
firewall-cmd --panic-off
```
- 查看是否拒绝
```
firewall-cmd --query-panic
```
- 查看所通过的服务
```
firewall-cmd --list-services
```
- 添加一个服务
```
firewall-cmd --add-service openvpn
```
- 永久添加一个服务
```
firewall-cmd --permanent --add-service openvpn
```
- 开启一个端口
```
firewall-cmd --zone=public --add-port=80/tcp --permanent    （--permanent永久生效，没有此参数重启后失效）
```
- 重新载入
```
firewall-cmd --reload
```
- 查看端口是否开启
```
firewall-cmd --zone= public --query-port=80/tcp
```
- 删除开放端口
```
firewall-cmd --zone= public --remove-port=80/tcp --permanent
```
