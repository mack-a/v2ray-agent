# VLESS XHTTP TLS 任意门模式设计

日期：2026-09-08

## 1. 目标与范围

为脚本增加 Xray `VLESS + XHTTP + TLS` 协议，使用“公网随机端口的 dokodemo-door 入站 -> 本机固定端口的 VLESS XHTTP TLS 入站”结构。功能覆盖部署、用户增删、账号展示、通用订阅和 Mihomo 订阅。

本功能只实现任意门模式，不实现 Nginx 路径反代模式，也不为 sing-box 生成配置或订阅节点。

## 2. 编号与实现边界

- 新协议类型编号为 `14`，名称为 `VLESS_XHTTP_TLS`。
- 协议类型编号和主菜单命令编号是两个独立的解析空间。主菜单已有命令 `14`（切换 ALPN）不会与协议类型 `14` 冲突；仓库内其他协议类型也已采用与主菜单命令相同的数字。
- 类型 `14` 仅加入 Xray 的安装选择、配置识别、用户管理、账号展示和订阅生成分支。
- 不将类型 `14` 加入 `customSingBoxInstall`、`initSingBoxClients`、sing-box 用户管理或 sing-box 订阅生成分支。
- XHTTP 不在 sing-box 官方支持的 V2Ray transport 列表中，因此不得生成看似可用但实际不受支持的 sing-box XHTTP 节点。

## 3. 网络结构

```text
直接连接：
客户端 -> 服务器公网随机 TCP 端口 -> dokodemo-door -> 127.0.0.1:45988 -> VLESS XHTTP TLS

CDN 连接：
客户端 -> CDN:443 -> CDN Origin Rule 将目标端口改写为随机端口
       -> dokodemo-door -> 127.0.0.1:45988 -> VLESS XHTTP TLS
```

Xray 配置中：

- `.inbounds[0]` 是仅监听 `127.0.0.1:45988` 的 VLESS XHTTP TLS 入站。
- `.inbounds[1]` 是监听公网随机端口的 dokodemo-door 入站，固定转发至 `127.0.0.1:45988`，网络仅为 TCP。
- 为 dokodemo-door 标签增加显式路由到 `z_direct_outbound`，避免全局路由规则影响本机回环转发。
- 内层入站保持在索引 `0`，复用现有 `.inbounds[0].settings.clients` 用户管理路径。

公网端口使用独立变量和独立初始化函数，避免与现有 Reality XHTTP 类型 `12` 的端口状态互相覆盖。初始化逻辑复用 Reality 风格：优先复用历史值，也允许手工输入，默认在 `10000-30000` 中随机选择未占用 TCP 端口。

## 4. XHTTP 与 TLS 参数

内层 VLESS 入站采用：

- `network: xhttp`
- `xhttpSettings.host`: 当前证书域名
- `xhttpSettings.path`: 复用 `randomPathFunction` 生成的 `/${currentPath}xHTTP`
- `xhttpSettings.mode: auto`，服务端接受客户端支持的 XHTTP 模式
- `security: tls`
- 证书路径复用 `/etc/v2ray-agent/tls/${domain}.crt` 和 `${domain}.key`
- TLS 最低版本 `1.2`
- `rejectUnknownSni: true`
- 面向源站使用 HTTP/1.1 或 HTTP/2，不要求源站开放 UDP/QUIC

直接节点使用 `mode=auto`。CDN 节点使用 `mode=packet-up`，以提高中间设备兼容性。客户端可与 CDN 使用 HTTP/3，但 CDN 到源站仍可回落为 HTTP/1.1 或 HTTP/2，因此随机源站端口只开放 TCP。

## 5. Nginx 与 CDN

XHTTP 传输本身不依赖 Nginx。类型 `14` 单独安装时跳过 Nginx 安装、伪装站、路径反代和 Nginx 启动流程，Xray 直接在随机公网端口接收 TLS。

不使用 Nginx 的主要差异是：

- 少一层真实 Web 服务指纹和路径分流能力。
- 随机端口直接暴露 Xray TLS 行为，扫描面与常规网站不同。
- 无法依赖 Nginx 在同一 `443` 端口上承载多个站点或协议。
- 部署更简单，且没有 Nginx 到 Xray 的额外转发层。

若同时安装其他依赖 Nginx 的协议，保留它们原有的 Nginx 行为，但类型 `14` 的数据流仍不经过 Nginx。

CDN 通常只接受客户端连接到其支持的边缘端口，不能让客户端直接连接任意随机端口。因此 CDN 节点固定使用边缘端口 `443`，并要求用户在 CDN 控制台配置 Origin Rule，把源站目标端口改写为脚本生成的随机端口。脚本只展示所需规则和参数，不调用 CDN API。

CDN 只是受控反向代理，但若源站端口对公网开放且缺少额外源站校验，知道域名、路径和账号的人仍可能绕过 CDN 直连。首版保持与现有脚本证书体系兼容，不自动配置 Cloudflare Authenticated Origin Pull；输出中应明确建议限制源站访问范围或启用额外源站认证。

现有在线订阅功能可能单独安装 Nginx 来托管订阅文件。该 Nginx 只服务订阅地址，不属于类型 `14` 的代理数据路径，也不能据此声称 XHTTP 必须使用 Nginx。

## 6. 安装与配置识别

`customXrayInstall` 增加类型 `14`，允许仅安装该类型，不自动补入类型 `0`。证书申请和校验流程仍需执行。

安装生成两个入站后，执行以下校验再重载服务：

- 随机端口必须是整数、位于允许范围且未被占用。
- 本机固定端口 `45988` 被占用时中止，并输出明确错误。
- 域名和证书文件必须存在。
- JSON 必须通过 `jq` 校验。
- Xray 配置必须通过 `xray run -test -confdir` 校验。
- 写配置采用临时文件和原子替换；重载失败时恢复原配置。

配置读取逻辑从 `.inbounds[1]` 读取公网端口，从 `.inbounds[0]` 读取域名、证书、路径和客户端。中文 `install.sh` 与英文 `shell/install_en.sh` 保持同一功能和编号。

## 7. 用户管理

`initXrayClients 14` 创建客户端，邮箱后缀为 `-VLESS_XHTTP_TLS`。新增用户时，将同一个用户 UUID 写入类型 `14` 的内层 VLESS 入站。

删除用户不再假设所有协议的客户端数组索引完全一致。界面选定用户后先取得 UUID，再在已安装的相关 Xray 配置中按 UUID 删除，避免旧配置或类型 `12` 历史缺失分支造成数组错位。类型 `12` 和类型 `14` 都补齐新增、删除用户处理。

每次修改用户后同样执行 JSON、Xray 配置校验和失败回滚，再重载服务。

## 8. 账号和订阅输出

每个用户最多生成以下逻辑节点：

- 一个直连节点：服务器公网地址或域名 + 随机公网端口，XHTTP `mode=auto`。
- 已配置 CDN 地址时，每个唯一 CDN 地址生成一个节点：CDN 地址 + `443`，SNI/Host 使用证书域名，XHTTP `mode=packet-up`。

CDN 地址先规范化并去重，避免同一地址重复生成节点。通用 URI 与 Mihomo YAML 是同一逻辑节点的两种表示，不在同一订阅格式中重复输出。

通用 URI 形态：

```text
vless://UUID@ADDRESS:PORT?encryption=none&security=tls&type=xhttp&sni=DOMAIN&host=DOMAIN&fp=chrome&alpn=h2&path=%2FRANDOMxHTTP&mode=MODE#NAME
```

Mihomo 节点包含：

```yaml
type: vless
network: xhttp
tls: true
servername: DOMAIN
alpn: [h2]
packet-encoding: xudp
client-fingerprint: chrome
xhttp-opts:
  path: /RANDOMxHTTP
  host: DOMAIN
  mode: auto # CDN 节点为 packet-up
```

类型 `14` 不生成 sing-box 节点，不进入 sing-box 独立订阅。用户同时安装其他协议时，现有 sing-box 订阅只保留 sing-box 已支持的协议，不因类型 `14` 多出占位项或重复项。

## 9. 验证与回归测试

实现阶段至少覆盖：

- `bash -n install.sh shell/install_en.sh`。
- 类型 `14` 只出现在 Xray 协议分支，不出现在 sing-box 菜单、客户端初始化、用户管理和订阅分支。
- 协议类型 `14` 与主菜单命令 `14` 分别在各自入口解析，互不影响。
- 生成配置中内层 XHTTP TLS 为入站 `0`，dokodemo-door 为入站 `1`，端口与路由正确。
- 单协议安装不会触发 XHTTP 数据路径所不需要的 Nginx 流程。
- 随机端口的历史复用、手工输入、冲突重试和范围校验。
- 用户新增和按 UUID 删除，包含类型 `12` 与类型 `14`。
- 通用 URI、Mihomo YAML 的路径编码、SNI、Host、端口和模式。
- CDN 地址去重，未配置 CDN 时不生成 CDN 节点。
- sing-box 订阅中不出现类型 `14`、`network: xhttp` 或重复节点。

## 10. 参考资料

- [Xray XHTTP 官方讨论](https://github.com/XTLS/Xray-core/discussions/4113)
- [Xray TLS 配置](https://xtls.github.io/en/config/transports/tls.html)
- [Xray Tunnel / dokodemo-door 入站](https://xtls.github.io/config/inbounds/tunnel.html)
- [Mihomo XHTTP 传输配置](https://wiki.metacubex.one/en/config/proxies/transport/)
- [sing-box V2Ray transport 支持列表](https://sing-box.sagernet.org/configuration/shared/v2ray-transport/)
- [Cloudflare 支持的代理端口](https://developers.cloudflare.com/fundamentals/reference/network-ports/)
- [Cloudflare Origin Rules 目标端口改写](https://developers.cloudflare.com/rules/origin-rules/)
- [Cloudflare Full (strict)](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/)
- [Cloudflare Authenticated Origin Pulls](https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/)
