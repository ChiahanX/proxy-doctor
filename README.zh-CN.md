<div align="center">

# 🩺 proxy-doctor

**一个客户端无关的 agent skill：在你动手改配置之前，先帮你诊断并修复 macOS 上的代理 / VPN 问题。**

[English](README.md) · **简体中文**

![Platform](https://img.shields.io/badge/平台-macOS-black?logo=apple)
![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![Skill](https://img.shields.io/badge/类型-agent%20skill-7C3AED)
![License](https://img.shields.io/badge/许可证-MIT-blue)
![Made for](https://img.shields.io/badge/为-🇨🇳%20中国大陆-red%20特化)

</div>

---

适用于 **Loon · Surge · Shadowrocket · Clash / ClashX / Mihomo · Stash · Quantumult X · sing-box · v2ray/xray**。

> **核心判断：** 大多数"代理不稳 / 慢 / 坏了"的问题，根因**不是配置**，而是
> **网络**（校园、企业网对代理流量限速 / DPI 干扰）或**换软件后的残留**。这个
> skill 的作用，就是拦住你"上来就改配置文件"的冲动，改走一套**先取证、后动手**
> 的有纪律的排查流程。

## ✨ 它能做什么

- **先识别客户端** —— 自动检测正在运行的软件及其配置目录，绝不假设是哪个。
- **网络优先诊断** —— 先证明问题出在网络、节点、还是配置。
- **默认只读** —— 在改动任何设置之前，先把证据采集齐。
- **跨客户端速查表** —— 同一套诊断，套到你正在用的任意客户端上。

## 🚀 快速上手

```bash
bash diagnose.sh          # 全量只读采集（自动识别客户端）
bash diagnose.sh quick    # 跳过较耗时的稳定性 / 握手探测
PROXY_IP=<你的服务器IP> bash diagnose.sh   # 顺带检查到代理服务器的路由
```

作为 Claude Code / agent skill 使用：把整个文件夹放进你的 skills 目录
（如 `~/.claude/skills/proxy-doctor`），遇到代理相关问题时会自动触发。

## 📦 文件构成

| 文件 | 作用 |
|---|---|
| **`SKILL.md`** | 排查方法论 + 跨客户端速查表：各客户端的配置格式、规则写法、兜底关键字（`FINAL` / `MATCH`）、默认端口、配置路径。 |
| **`diagnose.sh`** | **只读**采集器：自动识别客户端、判定谁在接管默认路由、区分真实网络 vs 全隧道、检出系统代理残留 / 死端口、显示 fake-ip DNS 状态、跑 8 连发稳定性测试、测试邮件 TLS 握手。 |

## 🇨🇳 针对中国大陆（GFW 环境）特化

这个 skill 默认的就是大陆的真实场景 —— 代理客户端跑在 **TUN + fake-ip** 模式、
链式节点、路径上有 GFW —— 并把通用"检查一下代理"建议里缺失的经验固化了进来：

- **根因通常是网络，不是配置。** 校园 / 企业网（`10.x` 网段）经常对代理流量限速或
  DPI 干扰；**同一份**配置换到家庭网就稳如磐石。**改任何东西之前，先换个网络复测。**
- **`fake-ip` 是正常现象。** 域名被解析成 `198.x` 之类占位地址不是污染 ——
  真正的连接由客户端接管。
- **邮件报 "An SSL error has occurred"**（Gmail / iCloud）→ 邮件域名落到了兜底策略
  （`FINAL` / `MATCH`），`url-test` 又选到一个连不通 Google / Apple 的节点。修法是把
  邮件域名钉死到稳定出口，并用 `openssl s_client` 验证。
- **换软件后的冲突**（如 Shadowrocket → Loon）→ 残留的系统代理仍指向一个已没人
  监听的死端口，把流量悄悄丢进黑洞。
- **墙内访问 Claude Code / Anthropic** —— 把正确的域名钉死走代理，以及"终端不一定
  继承系统代理"这个坑。

> 配套的 **`LOCAL.md`**（已被 git 忽略、绝不入库）保存任何与本机相关的锚点 ——
> 你用的客户端、源配置文件名、稳定出口名 —— 这样公开的 skill 保持通用，
> 你的私人备注留在本地。

## 🧭 设计原则

1. **先识别客户端。** 别假设，要么问、要么自动检测。
2. **网络优先。** 动配置前先换个网络复测。
3. **先只读。** 在确认前绝不改设置、不删文件。
4. **改前先备份；删除移废纸篓，绝不碰 iCloud 同步目录。**
5. **质疑自己的"确凿结论"** —— 用一个能真正证伪它的实验去验证。

## 📄 许可证

[MIT](LICENSE)
