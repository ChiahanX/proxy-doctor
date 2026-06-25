<div align="center">

# 🩺 proxy-doctor

**A client-agnostic agent skill that diagnoses and fixes proxy / VPN problems on macOS — before you blame the config.**

**English** · [简体中文](README.zh-CN.md)

![Platform](https://img.shields.io/badge/platform-macOS-black?logo=apple)
![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![Skill](https://img.shields.io/badge/type-agent%20skill-7C3AED)
![License](https://img.shields.io/badge/license-MIT-blue)
![Made for](https://img.shields.io/badge/tuned%20for-🇨🇳%20mainland%20China-red)

</div>

---

Works for **Loon · Surge · Shadowrocket · Clash / ClashX / Mihomo · Stash · Quantumult X · sing-box · v2ray/xray**.

> **The core insight:** most "my proxy is unstable / slow / broken" problems are
> *not* the config. They're the **network** (campus & enterprise networks
> throttling proxied traffic) or **stale residue from a previously installed
> app**. This skill stops you from blindly editing config files and walks a
> disciplined, evidence-first diagnosis instead.

## ✨ What it does

- **Identifies the client first** — auto-detects the running app and its config dir; never assumes.
- **Network-first diagnosis** — proves whether the problem is the network, the node, or the config.
- **Read-only by default** — gathers evidence before changing a single setting.
- **Cross-client cheat-sheet** — one diagnosis maps onto whichever client you run.

## 🚀 Quick start

```bash
bash diagnose.sh          # full read-only collection (auto-detects client)
bash diagnose.sh quick    # skip the slower stability / handshake probes
PROXY_IP=<your-server-ip> bash diagnose.sh   # also check the route to your proxy server
```

As a Claude Code / agent skill, drop the folder into your skills directory
(e.g. `~/.claude/skills/proxy-doctor`) and it activates on proxy-related questions.

## 📦 Contents

| File | Purpose |
|---|---|
| **`SKILL.md`** | The methodology + a cross-client cheat-sheet: config format, rule syntax, fallback keyword (`FINAL` / `MATCH`), default ports, and config paths per client. |
| **`diagnose.sh`** | A **read-only** collector: auto-detects the client, identifies who owns the default route, tells real-network vs full-tunnel apart, finds system-proxy residue / dead ports, shows fake-ip DNS state, runs an 8-shot stability loop, and tests mail TLS handshakes. |

## 🇨🇳 Tuned for mainland China (behind the GFW)

This skill assumes a real-world mainland setup — a proxy client in **TUN +
fake-ip** mode, chained nodes, and the GFW in the path — and bakes in lessons
that generic "check your proxy" advice misses:

- **Network is usually the root cause, not the config.** Campus / enterprise
  networks (`10.x`) routinely throttle or DPI proxied traffic; the *same* config
  is rock-solid on a home network. **Re-test on another network before editing anything.**
- **`fake-ip` is normal.** Domains resolving to `198.x` placeholders aren't
  pollution — the client handles the real connection.
- **Mail "An SSL error has occurred"** (Gmail / iCloud) → the mail domain fell
  through to the fallback policy (`FINAL` / `MATCH`) and `url-test` picked a node
  that can't reach Google / Apple. Fix by pinning the mail domain to a stable
  egress, verified with `openssl s_client`.
- **App-switch conflicts** (e.g. Shadowrocket → Loon) → leftover system proxy
  pointing at a dead port silently blackholes traffic.
- **Claude Code / Anthropic access behind the GFW** — pinning the right domains
  to proxy, and the terminal-vs-system-proxy gotcha.

> A companion **`LOCAL.md`** (git-ignored, never committed) holds any
> machine-specific anchors — your client, source config file, and stable egress —
> so the public skill stays generic while your private notes stay local.

## 🧭 Design principles

1. **Identify the client first.** Don't assume; ask or auto-detect.
2. **Network-first.** Re-test on a different network before touching config.
3. **Read-only first.** Never change settings or delete files before confirming.
4. **Back up before editing; move deletions to Trash, never the iCloud sync dir.**
5. **Question your own "certain" conclusions** with an experiment that can actually falsify them.

## 📄 License

[MIT](LICENSE)
