---
name: proxy-doctor
description: >
  Diagnose and fix proxy/VPN client problems on macOS — works for ANY client
  (Loon, Surge, Shadowrocket, Clash/ClashX/Mihomo, Stash, Quantumult X, sing-box,
  v2ray/xray). Use whenever the proxy is unstable, slow, or high-latency; a site
  won't open or is slow; Mail shows "An SSL error has occurred and a secure
  connection to the server cannot be made"; right after switching proxy apps or
  editing a config/rule file; or any "网不稳 / 延迟高 / 代理坏了 / 换了软件 / 改了代理文件"
  complaint. ALWAYS identify which client is in use FIRST (ask the user or
  auto-detect), then apply that client's file format and paths. Enforces a
  network-first, read-only-first diagnostic discipline over blind config edits.
---

# 代理客户端问题自查（macOS，客户端无关）

代理客户端（Loon / Surge / Shadowrocket / Clash·Mihomo / Stash / Quantumult X / sing-box / v2ray…）的**核心机制都一样**：TUN 接管或本地 HTTP/SOCKS 端口、fake-ip DNS、规则自上而下匹配 + 兜底策略、策略组(select/url-test/fallback)、源配置 vs 运行缓存、改完要 reload。**差别只在配置语法和路径。** 所以这套排查方法论通用——先识别软件，再套用该软件的格式。

> 若你长期维护着某客户端的源配置，建议把该客户端专属的决策/踩坑单独记在一份本地笔记里（如同目录的 `LOCAL.md`，本机私有、不入库），改配置前先读它。其它客户端按下面 §1 的对照表换算。

## 0. 黄金法则（每次先念）

1. **先确认是哪个客户端**（§1）。不知道就**问用户**，或用诊断脚本自动识别；别假设是 Loon。
2. **网络优先**：不稳/高延迟，**先换一个网络验证**（校园/企业网 `10.x` 常被 DPI/限速；家庭网 `192.168.x` 实测同配置 8/8 稳 ~0.4s）。配置只能改善，网络才是根因。
3. **先只读、后动手**：排查命令全只读。要改设置/删文件前，先列出来让用户确认。
4. **改文件先备份**：`cp x x.bak.$(date +%Y%m%d%H%M%S)`；删残留**移废纸篓**而非永久删。
5. **质疑自己的"确凿结论"**：曾把"本机是香港网络"当结论，实为全隧道把 `en0-bind` 也劫持了，HK IP 是代理出口而非真实网络。下结论前用能区分两种情况的实验验证（§3）。
6. **分清单位与时效**：日志时间戳可能是毫秒不是秒、可能是几个月前的陈旧记录，别当实时证据。

## 1. 第一步：识别客户端 + 换算配置格式

```bash
bash ~/.claude/skills/proxy-doctor/diagnose.sh        # 全量（含客户端识别）
bash ~/.claude/skills/proxy-doctor/diagnose.sh quick  # 跳过耗时探测
```

脚本 §1 会列出运行中的客户端及其配置目录。**识别不到就直接问用户用的是哪个、配置文件在哪。** 确认后按下表换算（语法不同、思路相同）：

| 客户端 | 配置格式 | 规则写法示例 | 兜底关键字 | 默认混合端口 | macOS 配置目录 |
|---|---|---|---|---|---|
| **Loon** | INI 类 `.lcf` | `DOMAIN-SUFFIX,gmail.com,策略组` | `FINAL` | TUN（7221/7222 可选） | `~/Library/Application Support/com.loon.Loon` |
| **Surge** | INI 类 `.conf`（与 Loon 几乎同语法） | 同上 | `FINAL` | TUN | `~/Library/Application Support/com.nssurge.surge-mac` |
| **Shadowrocket** | `.conf`（Surge 家族语法） | 同上 | `FINAL` | — | iOS 为主；iCloud `iCloud~com~liguangming~Shadowrocket/Documents` |
| **Quantumult X** | `.conf`（自有语法） | `host-suffix, gmail.com, 策略组` | `final` | — | iOS 为主 |
| **Clash / Mihomo / ClashX** | YAML | `- DOMAIN-SUFFIX,gmail.com,策略组` | `MATCH` | `7890` | `~/.config/mihomo`、`~/Library/Application Support/ClashX`/`...ClashX.Meta` |
| **Stash** | Clash 核 YAML | 同 Clash | `MATCH` | — | `~/Library/Application Support/com.gozap.stash` |
| **sing-box** | JSON | `route.rules[]` 数组 | `final` outbound | TUN | `~/Library/Application Support/sing-box` |
| **v2ray / xray** | JSON | `routing.rules[]` | 默认 outbound | 本地 inbound 端口 | 各自配置路径 |

> 概念对应：Surge 家族的「策略组 Proxy Group」≈ Clash 的 `proxy-groups` ≈ sing-box 的 `selector/urltest` outbound；`url-test` 自动选点各家都有；fake-ip、TUN、规则自上而下匹配各家通用。

## 2. 关键判定：当前是不是"全隧道"，raw 测试可不可信

误判常源于"以为 `curl --interface en0` 绕过了代理"。**先确定再解读**：

```bash
traceroute -n -i en0 -w 1 -q 1 -m 3 1.1.1.1 | head -4
```
- 第一跳是**真实网关**（`192.168.x`/`10.x`）→ en0 确实绕过隧道，raw 结果可信。
- 第一跳是 `198.19.x`/客户端隧道地址 → **全隧道**，"raw"出口 IP 是代理出口，不能当真实网络。

佐证真实网络位置（不受隧道影响）：`ipconfig getpacket en0 | grep -iE "router|domain_name_server"`、Wi-Fi SSID。

## 3. 症状 Playbook（与客户端无关，修法按 §1 换算语法）

### A) 不稳定 / 延迟高
1. 跑诊断脚本 §7 稳定性。剧烈抖动（0.5→7,8s）或硬失败 → **几乎一定是网络层**。
2. **换网络复测**。同配置在家稳、在校园网烂 = 网络 DPI/限速，不是 Mac、不是配置。
3. 仍不稳才看节点：在客户端里换节点/入口，或检查 `url-test` 是否选了"能测速却连不通目标"的坏节点。
4. 个别被 MITM 的站点单独慢 ~5s（其余正常）→ **Mac 对 MITM 伪证书做 OCSP 吊销检查超时**，非网络问题；精简 MITM 规则、网页去广告改用浏览器 uBlock Origin。

### B) 邮件报 "An SSL error has occurred"（Gmail / iCloud 反复出现）
**根因（所有客户端通用）**：fake-ip 模式下邮件域名若无专门规则，落到兜底策略（`FINAL`/`MATCH`）；该策略组 url-test 一旦选到对 Google/Apple 不可达的节点，TLS 拿不到证书 → 邮件 App 报 SSL 错误。**与 macOS、证书、邮件 App 本身无关。**

诊断（透过隧道测真实握手，客户端无关）：
```bash
openssl s_client -connect imap.gmail.com:993 -servername imap.gmail.com </dev/null | grep -iE "issuer=|Verify return"
```
拿到 `Google Trust Services`/`Apple Inc.` 证书且 `Verify return code: 0` → 正常；`no peer certificate available` → 当前节点连不通目标。

**修法**：把邮件域名钉死到稳定入口，加在规则段**顶部**（按 §1 换算语法）。Surge 家族（Loon/Surge/Shadowrocket）：
```
DOMAIN-SUFFIX,gmail.com,<稳定可用的策略组>
DOMAIN-SUFFIX,googlemail.com,<稳定可用的策略组>
DOMAIN-SUFFIX,mail.me.com,<稳定可用的策略组>    # 只钉 mail.me.com，别钉整个 icloud.com
```
（`<稳定可用的策略组>` 换成你配置里实测对 Google/Apple 稳定的那个入口/策略组名。）
Clash/Stash（YAML，加在 `rules:` 顶部）：`- DOMAIN-SUFFIX,gmail.com,<稳定可用的策略组>`。
改完 **reload + 完全退出重开邮件 App**。fake-ip 把这些域名解析成 `198.0.x.x` 是正常占位。

### C) 某网站打不开 / 解析到假 IP
1. 三方 DNS 对比：`nslookup <域名> 8.8.8.8` vs `1.1.1.1` vs 系统解析。
2. 找命中哪条规则：在配置/远程规则里搜该域名，确认落到代理组而非 `DIRECT`/`REJECT`。
3. 无专门规则 → 落兜底 → 同 B) 钉死思路。

### D) 换了代理软件后出问题（A 软件 ↔ B 软件 冲突）
TUN 类客户端走系统扩展，不依赖本地端口；旧软件最常见残留是**系统代理仍指向旧软件早已不监听的死端口**（如 `127.0.0.1:7890/7222/1080`），流量被丢进黑洞。
1. 诊断脚本 §4 检出哪些网络服务系统代理还开着、端口有没有人监听（`lsof` 无监听 = 死代理）。
2. 关残留代理（可逆）：`networksetup -setwebproxystate / -setsecurewebproxystate / -setsocksfirewallproxystate "<服务>" off`。
3. 多余网络服务条目：`networksetup -removenetworkservice "<旧软件名>"`。
4. 清容器残留：**先用元数据核对归属**（`PlistBuddy -c "Print :MCMMetadataIdentifier"`、`find ~/Library -iname "*软件名*"`），确认后**移废纸篓**。⚠️ `~/Library/Mobile Documents/iCloud~...` 是 **iCloud 同步目录**，本机删会同步删到其它设备，**默认不动、单独问用户**。
5. 别忘 shell/git/npm 的 `*_proxy` 残留（脚本 §5）。

### E) Claude Code / Anthropic 服务在墙内连不上、403、更新失败
1. TUN 模式下终端流量本应被接管；若某工具走了不被 TUN 捕获的路径或要显式代理，可设 `https_proxy/http_proxy/all_proxy`（脚本 §5 已查残留）。
2. 把 Anthropic/Claude 全套域名钉死走代理。现成多客户端规则集：**`xiaolai/anthropic-claude-surge-rules-set`**（GitHub，含 Surge/Clash/sing-box/Loon 格式，覆盖 API/CLI/二进制更新/遥测）。
3. Claude Code 的 API 端点与 claude.ai 网页不是同一个，分别确认可达。

## 4. 改配置必读

- **源文件 vs 运行缓存**：改动要落在**源配置文件**（你的 `.lcf`/`.conf`/`.yaml`），别只改运行缓存（如 Loon `tempFile/lastConfig`、Clash 的 `~/.config/.../runtime`）——reload/更新订阅会被源文件覆盖。
- 改完必须在客户端里**重新载入配置**才生效；改已建连的服务（邮件等）还要完全退出重开那个 App。
- 多数配置已自带**远程 GEOIP/CN 规则**，别在本地规则段重复加 GEOIP/CN，别乱改 CN REGION 排序（Loon 细节见 Configs/CLAUDE.md）。

## 5. 收口：结论怎么写（假设排序表 → 根因 → 修法）

不要一上来就改配置。先给一张**按概率排序的假设表**，每条配一个能证伪它的诊断命令，据实测收敛到根因：

| # | 假设（按概率排序） | 证伪/验证命令 | 实测 | 结论 |
|---|---|---|---|---|
| 1 | 网络层（校园/企业网 DPI/限速） | 换网络后跑稳定性测试 | … | … |
| 2 | 当前节点连不通目标 | `openssl s_client` 看证书 | … | … |
| 3 | 旧软件系统代理残留（死端口） | `networksetup -get*` + `lsof` | … | … |
| 4 | 规则落到兜底坏节点 | 搜规则命中 + 看策略组 | … | … |
| 5 | Mac 特有：MITM 证书 OCSP 超时 | 对比 MITM 站 vs 非 MITM 站延迟 | … | … |

收口给用户："**用的哪个客户端 + 先行结论 + 这张表 + 修法（按该客户端语法）+ 生效步骤**"。**诚实**：网络是根因就说网络（别甩锅给配置/Mac）；探测被隧道污染或自己判断错了，就明说并用新实验纠正；没权限看到的（如 root 才能看的 socket）讲清不影响结论的边界。
