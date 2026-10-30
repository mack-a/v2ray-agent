# Socks5 多落地机与入站 Tag 分流设计方案

本文记录 Socks5 出站的设计与实现约束。方案已在 `install.sh` 和 `shell/install_en.sh` 中实现，本地测试不修改服务器运行时配置。GitHub Issue [#1215](https://github.com/mack-a/v2ray-agent/issues/1215) 和 [#1225](https://github.com/mack-a/v2ray-agent/issues/1225) 作为需求背景和使用案例，具体实现不绑定某个协议名称。

## 1. 目标行为

### 审查结论

当前方案的功能方向可行，可以覆盖“按入站 tag 全部分流”和“按入站 tag 加目标条件分流”。实现前必须落实以下四个约束，否则配置可能通过语法检查但路由结果不符合预期：

1. 入站扫描只能读取配置片段中的 `.inbounds[]`，排除合并后的 `config.json`，并忽略无效 JSON 和无 tag 的入站。
2. 路由不能只靠 `01_`、`02_` 文件名排序。必须由编译器生成确定的最终规则顺序，并处理现有 WARP、IPv6、直连、拦截和白名单规则的冲突。
3. 同一入站同时有目标规则和“全部流量”规则时，目标规则必须先于全部规则；用户输入的优先级若违反这一点，应拒绝保存或自动规范化。
4. 现有“全局转发”会删除其他出站和分流规则，不能直接复用到新菜单；新实现必须采用可回滚的托管配置，不能以删除无关规则作为设置步骤。

Socks5 出站需要同时支持 sing-box 和 Xray。用户先维护多个 Socks5 落地机，再创建“入站 tag 到 Socks5 出站”的分流规则。

分流时从当前核心配置动态读取入站 tag，用户选择一个或多个 tag，然后选择分流范围：

* **全部流量**：选中的入站 tag 收到的所有流量都走指定 Socks5 落地机。
* **目标匹配**：选中的入站 tag 只有命中域名、geosite/rule-set 或 IP 规则的流量走指定 Socks5 落地机。
* **目标规则全局匹配**：不选择入站 tag 时，保留现有按域名/geosite/IP 分流的能力，对所有入站生效。

协议名称、端口和 tag 都不能写死在脚本中。配置新增协议或用户手工增加入站后，重新打开分流菜单即可看到新的 tag。

## 2. 改造前实现审计

改造前 Socks5 出站入口在 [install.sh](../install.sh) 中：

* `socks5Routing()` 和 `socks5OutboundRoutingMenu()` 负责菜单（约 8453、8529 行）。
* `setSocks5Outbound()` 只询问一组 IP、端口、用户名和密码，并固定生成 `socks5_outbound`（约 8883 行）。
* sing-box 写入 `socks5_outbound.json`；Xray 通过 `addXrayOutbound socks5_outbound` 生成同名出站。
* `setSocks5OutboundRouting()` 只询问一组域名/geosite，生成 `socks5_01_outbound_route.json`；Xray 则把规则追加到 `09_routing.json`（约 8933 行）。
* `addSingBoxRouteRule()` 当前只生成目标规则，没有 `inbound` 参数（约 3957 行）。
* sing-box 配置通过 `sing-box merge -C ... -D ...` 合并，配置文件按名称排序，路由规则按最终数组顺序依次匹配。

现有实现的问题是：

1. 只有一个 Socks5 节点，无法按不同落地机分配流量。
2. 规则只按目标匹配，无法限定入站 tag。
3. “全部流量”与“目标匹配”没有明确的交互和配置模型。
4. 全局模式依赖默认出站顺序；新增多个出站后会产生歧义。
5. 当前生成器用 heredoc 直接插入凭据，特殊字符可能破坏 JSON。
6. 现有清理逻辑有 `removeSingBoxConfig socks5_outbound.json` 的调用，而 helper 会自行追加 `.json`，迁移和卸载时需要处理旧文件残留。

## 3. 设计原则

### 3.1 入站 tag 动态发现

菜单打开时按当前核心读取入站配置。扫描实际配置目录下所有 JSON 片段中的 `.inbounds[]`，不限制用户自定义文件名，不扫描合并后的 `config.json`，避免同一入站被重复读取：

* sing-box：扫描 `${singBoxConfigPath}*.json` 的 `.inbounds[]`，收集非空 `.tag`。
* Xray：扫描 `${configPath}*.json` 的 `.inbounds[]`，收集非空 `.tag`。

扫描器必须逐文件执行 `jq` 校验；无效 JSON、缺少 `inbounds` 数组或缺少 `tag` 的条目跳过并记录可读错误，不能让一个坏片段导致菜单整体退出。tag 列表以“核心 + tag + 监听地址 + 端口”去重；同名 tag 出现在不同核心时仍视为两条记录。

列表应去重，并同时显示核心、协议类型、tag、监听地址和端口，方便用户确认选择。脚本只保存用户最终选择的 tag，不维护协议名称到 tag 的硬编码映射。

共存模式下 sing-box 和 Xray 分别列出自己的 tag。两个核心的 tag 不要求相同，规则必须带 `core` 字段，避免把 sing-box tag 写入 Xray 配置。

### 3.2 明确区分分流范围

规则必须有 `scope`：

* `all`：只需要 `inbound_tags`，不填写域名、rule-set 或 IP。
* `match`：必须填写非空 `inbound_tags`，并且至少填写一种目标条件。
* `target_only`：不填写 `inbound_tags`，只按目标条件匹配，用于兼容现有的全局域名/geosite 分流。

用户选择“全部流量”时，生成只包含入站条件的规则；不能通过写入空域名数组来间接表示全部流量。

### 3.3 核心配置使用稳定 tag

节点显示名称可以修改，但核心 outbound tag 不能随名称变化。旧节点可以保留 `socks5_outbound`，新节点使用稳定 ID 派生 tag。

## 4. 配置模型

建议增加核心无关的状态目录：

```text
/etc/v2ray-agent/socks5/
  outbounds.json       # 落地机清单，包含凭据
  routes.json          # 分流清单
  backup/              # 修改前快照
```

### 4.1 落地机清单

```json
{
  "version": 1,
  "nodes": [
    {
      "id": "node-01",
      "name": "香港落地",
      "server": "203.0.113.10",
      "server_port": 1080,
      "version": "5",
      "username": "user-a",
      "password": "secret-a",
      "core_tags": {
        "sing-box": "socks5_node-01",
        "xray": "socks5_node-01"
      },
      "enabled": true,
      "legacy": false
    }
  ]
}
```

约束：

* `id` 只允许小写字母、数字和短横线，创建后保持不变。
* `core_tags.sing-box` 和 `core_tags.xray` 分别是两个核心实际使用的 outbound tag。
* `server` 支持 IPv4、IPv6 字面量和域名；端口必须是 1～65535 的整数。
* 当前只开放 SOCKS5，`version` 为后续扩展 SOCKS4/HTTP 保留。
* 禁用节点不能被新规则选择；已有规则引用禁用节点时必须提示改绑。
* manifest 和生成的 sing-box/Xray 出站片段都包含凭据，文件权限统一设为 `600`。

### 4.2 分流规则清单

```json
{
  "version": 1,
  "defaults": {"sing-box": null, "xray": null},
  "routes": [
    {
      "id": "route-01",
      "core": "sing-box",
      "scope": "all",
      "inbound_tags": ["实际读取到的入站tag"],
      "domains": [],
      "rule_sets": [],
      "ip_cidrs": [],
      "outbound_node": "node-01",
      "priority": 10,
      "enabled": true
    },
    {
      "id": "route-02",
      "core": "xray",
      "scope": "match",
      "inbound_tags": ["另一个实际入站tag"],
      "domains": ["example.com"],
      "rule_sets": [],
      "ip_cidrs": [],
      "outbound_node": "node-01",
      "priority": 20,
      "enabled": true
    }
  ]
}
```

字段语义：

* `core` 只能是 `sing-box` 或 `xray`。
* `inbound_tags` 保存用户从当前核心菜单中选择的真实 tag；空数组只允许用于 `target_only`。
* `scope=all` 表示选中的入站全部流量走指定节点。
* `scope=match` 表示入站条件与目标条件同时满足时走指定节点。
* `scope=target_only` 表示只按目标条件匹配所有入站。
* `domains`、`rule_sets`、`ip_cidrs` 之间使用 OR 语义。编译器应把不同类型展开为多条明确规则，避免依赖核心对混合字段的隐式 AND/OR 解释。
* 同一条规则中的多个 `inbound_tags` 是 OR 关系。
* `priority` 越小越先匹配；重复的来源和目标组合必须提示冲突。
* `outbound_node` 必须引用启用节点，生成核心配置时使用对应的 `core_tags`。

## 5. 动态入站选择流程

“添加分流规则”进入后按以下顺序交互：

1. 选择核心：sing-box、Xray；共存模式不能把两个核心混在一条规则中。
2. 读取并展示该核心当前所有入站 tag，可多选。
3. 选择分流范围：全部流量、按域名/geosite/IP、只按目标匹配所有入站。
4. 选择 Socks5 落地机。
5. 输入优先级并预览最终规则。
6. 保存 manifest，生成核心片段，校验后 reload。

如果入站配置发生变化，下一次打开菜单重新扫描。保存规则时检查 tag 是否仍存在；不存在的 tag 不能静默生成，应提示用户重新选择。

## 6. 核心配置生成

### 6.1 sing-box

建议生成：

```text
zz_socks5_outbounds_tail.json   # 所有启用节点，排在原出站之后
zz_socks5_routes.json           # 所有 Socks5 路由和 rule-set
```

全部流量规则使用选中的入站 tag 和 Socks5 outbound：

```json
{
  "inbound": ["实际入站tag"],
  "action": "route",
  "outbound": "socks5_node-01"
}
```

对于仍使用旧语法的 sing-box 版本，兼容输出顶层 `outbound` 字段。实现应根据已安装版本选择格式，内部规则模型不绑定某一种 JSON 写法；版本探测失败时应停止生成并提示，而不是猜测格式。

目标匹配规则在同一条规则中加入 `rule_set`、`domain`/`domain_suffix` 或 `ip_cidr`。如果一个 manifest 规则同时含有多种目标类型，编译器展开为多条规则，每条规则保留相同的入站条件和 outbound。

### 6.2 Xray-core

生成包含所有启用节点的 `zz_socks5_outbounds_tail.json`，每个节点一个 `socks` outbound，tag 使用 `core_tags.xray`。Xray 的 `tail` 文件名保证新节点追加到原出站之后，避免意外改变默认出站。读取各片段中的 routing 配置，合并后写入 `zz_socks5_routes.json`，保留原 `09_routing.json` 等源文件；若还有按文件名排序更靠后的自定义 routing 段，拒绝发布并提示整理布局，避免覆盖生成结果。

全部流量规则：

```json
{
  "type": "field",
  "inboundTag": ["实际入站tag"],
  "outboundTag": "socks5_node-01"
}
```

目标匹配规则在同一条 Xray 规则中加入 `domain`、`ip` 等条件。geosite 继续使用 Xray 当前的 `geosite:<name>` 表达方式。

如果当前 Xray 配置没有可用入站 tag，菜单不显示协议级选择；用户仍可以使用 `target_only` 或全局默认节点。

## 7. 路由优先级

Socks5 规则先按用户优先级排序；优先级相同时按以下顺序编译：

1. 指定入站 + 指定目标。
2. 指定入站 + 全部流量。
3. 仅目标匹配所有入站。
4. 用户设置的全局默认节点。

“全部流量”规则必须排在同一入站的目标规则之后，否则目标规则永远不会命中。编译排序应先按用户 `priority`，再以“目标规则优先于全部规则、带入站条件优先于 target-only”作为稳定 tie-break；如果用户优先级明确造成同一入站的全部规则早于目标规则，应拒绝保存并说明原因。若用户希望某入站的大部分流量走节点 A、个别目标走节点 B，应把目标规则优先级设得更高。

现有 WARP、IPv6、block、direct 和白名单规则也会参与最终路由。sing-box 配置目录的数字前缀只能控制片段合并顺序，不能代替全局路由优先级。实现时要明确这些功能与 Socks5 的冲突策略，必要时在生成最终配置前统一整理 route 数组。

因此，生成器必须建立一个明确的路由编译边界：读取当前核心的所有托管路由片段，保留非 Socks5 规则，移除上一版本生成的 Socks5 规则，再按统一排序写回一个托管片段或最终 route 数组。不能简单新增一个更大的数字前缀文件，期待它覆盖已经排在前面的直连或默认规则。Xray 同样必须在 `routing.rules` 中完成同一排序，不能只向 `09_routing.json` 末尾追加。

现有来源限制和明确的拦截规则优先；Socks5 显式规则优先于现有 WARP、IPv6 和直连目标分流，未命中时保留这些原规则的相对顺序。sing-box 的 sniff/resolve/DNS 处理在最终选路之前。对于本脚本的 SOCKS5 入站白名单，托管规则与允许条件取交集后插入白名单内，保留最后的拒绝规则。

全局模式使用显式默认：sing-box 写入 `route.final`，Xray 添加显式兜底规则。不能依赖多个 outbound 的文件顺序。

## 8. 菜单设计

```text
Socks5 出站
1. 落地机管理
   1) 添加  2) 查看  3) 编辑  4) 删除  5) 测试连接
2. 添加分流规则
   1) 选择核心
   2) 动态选择入站 tag
   3) 全部流量 / 目标匹配 / 目标全局匹配
   4) 选择 Socks5 落地机
3. 查看生效规则
4. 删除或编辑规则
5. 设置全局默认落地机
6. 卸载 Socks5 出站
```

交互要求：

* tag 列表来自实际配置文件，显示协议、tag、监听地址和端口。
* 不出现固定的 `VLESSRealityGRPC`、`VLESSReality` 等协议选项；它们只能作为动态扫描后的普通 tag 示例。
* 选择“全部流量”后不再询问域名，直接生成入站级规则。
* 删除节点前列出引用它的所有规则，要求改绑或确认级联删除。
* 中英文脚本的扫描、菜单、校验和生成结果保持一致。

## 9. 旧配置迁移

首次使用新菜单时导入现有单节点配置：

* sing-box：读取 `socks5_outbound.json`，迁移为一个节点，并保留 `core_tags.sing-box=socks5_outbound`。
* Xray：读取 `socks5_outbound.json`，迁移为一个节点，并保留 `core_tags.xray=socks5_outbound`。
* sing-box 读取 `socks5_01_outbound_route.json`；Xray 读取 `09_routing.json` 中 `outboundTag=socks5_outbound` 的规则。
* 旧目标规则迁移为 `scope=target_only`，不自动添加入站 tag，保持原有行为。
* 旧配置迁移前创建备份；生成和核心校验失败时恢复旧文件。

## 10. 校验、重载和回滚

每次添加、编辑、删除节点或规则都按以下顺序处理：

1. 校验节点、核心 tag、入站 tag、目标条件、优先级和 outbound 引用。
2. 使用 `jq --arg/--argjson` 生成临时 JSON，避免凭据和 tag 破坏配置。
3. sing-box 执行 `merge` 和 `check`；Xray 执行 `run -test -confdir`。
4. 校验成功后逐文件原子替换 manifest、托管核心片段和 sing-box 合并配置，再通过 systemd/OpenRC 重启涉及的核心并检查服务状态。修改过程中持有出站锁，并检测配置源是否被其他操作改动。旧的破坏式全局转发流程已移除。
5. 发布或重启失败时恢复本次修改过的文件，并再次重启核心；恢复也失败时保留私有备份目录并明确报告。成功操作的修改前快照保存在 `backup/`，权限受私有目录限制。

完整配置和密码不得写入普通日志；查看配置时只显示节点名称、地址、端口、核心 tag 和规则，不显示密码。

## 11. 验收标准

* 添加三个 Socks5 落地机后，sing-box 和 Xray 都生成唯一稳定的 outbound tag。
* 新增一个入站配置后，重新打开菜单可以看到新 tag，无需修改脚本代码。
* sing-box 选择任意一个或多个入站 tag 的“全部流量”后，所有这些入站流量都经过选定 Socks5。
* Xray 选择任意可用入站 tag 的“全部流量”后，行为与 sing-box 一致。
* 选择“目标匹配”时，只有选定入站且命中目标规则的流量走 Socks5。
* 选择“目标全局匹配”时，保持旧的按域名/geosite/IP 分流能力。
* 同一入站同时存在目标规则和全部流量规则时，目标规则按优先级先命中。
* 删除或禁用节点不会留下指向不存在 outbound tag 的规则。
* 旧单节点配置迁移后，原有目标分流行为不变。

验证包括：

* `bash -n install.sh`、`bash -n shell/install_en.sh`。
* fixture 覆盖动态 tag 扫描、单 tag、多 tag、全部流量、目标匹配、三节点和冲突规则。
* sing-box `merge`/`check`，检查最终 route 规则顺序和 outbound。
* Xray `run -test -confdir`，检查 `inboundTag`、目标条件和 `outboundTag`。
* 端到端验证每个核心的入站 tag、全部流量和目标匹配确实连接到选定落地机。

## 12. 实施顺序（已完成）

1. 抽出双核心共用的节点 manifest、规则 manifest、备份和迁移逻辑。
2. 实现 sing-box/Xray 入站 tag 动态扫描和菜单展示。
3. 实现多 Socks5 outbound 生成和节点管理。
4. 实现 `all`、`match`、`target_only` 三种规则编译。
5. 实现 sing-box、Xray 各自的路由优先级、全局默认和回滚。
6. 重构中英文菜单并完成迁移、配置校验和端到端测试。

参考：[sing-box Route Rule](https://sing-box.sagernet.org/configuration/route/rule/)、[sing-box Rule Action](https://sing-box.sagernet.org/configuration/route/rule_action/)、[sing-box 配置合并](https://sing-box.sagernet.org/configuration/)、[Xray Routing](https://xtls.github.io/en/config/routing.html)。

## 13. 实现与验证记录

入口：分流工具 → Socks5 分流 → Socks5 出站。节点支持添加、编辑、删除、启停与连接测试；规则支持添加、编辑、删除和启停。选择 tag 后可直接选择“全部流量”；留空 tag 创建所有入站共用的目标规则。全局默认按核心独立设置，留空可恢复原默认。

旧节点按核心独立导入并保留原 tag；旧规则保存 `legacy_rule` 与规则集定义，避免迁移时把正则或复合条件变宽。通过核心原始合并结果识别旧默认出站，不仅根据规则文件是否存在进行推断。首次成功保存后才清理已导入的旧配置。

回归测试文件：`checks/test_socks5_outbound.py`。运行方式：

```bash
SING_BOX_BIN=/path/to/sing-box XRAY_BIN=/path/to/xray \
  python3 -m unittest discover -s checks -p 'test_socks5_outbound.py' -v
```

已使用 sing-box 1.14.4 和 Xray 26.3.27 执行配置校验与本地 TCP 流量验证，覆盖三节点、按入站全部转发、目标覆盖、全局目标规则、显式默认、旧配置迁移、卸载保留其他配置、校验失败不发布和双核心重启失败回滚。服务管理调用在自动化测试中使用隔离替身；实际 Linux systemd/OpenRC 环境仍需安装验证。UDP 是否可用取决于核心与上游 SOCKS5 服务的 UDP 支持，本次真实流量验证覆盖 TCP。
