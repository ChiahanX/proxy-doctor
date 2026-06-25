# proxy-doctor

A client-agnostic agent skill for diagnosing and fixing **proxy / VPN client
problems on macOS** — works for Loon, Surge, Shadowrocket, Clash / ClashX /
Mihomo, Stash, Quantumult X, sing-box, and v2ray/xray.

It encodes a hard-won methodology: **identify the client first → diagnose the
network before the config → rank hypotheses → only then edit**. Most "my proxy
is unstable / slow / broken" problems turn out to be the *network* (campus /
enterprise networks throttling proxied traffic) or *stale residue from a
previously installed app* — not the config. This skill stops you from blindly
editing config files.

## Contents

- **`SKILL.md`** — the methodology, plus a cross-client cheat-sheet (config
  format, rule syntax, fallback keyword `FINAL`/`MATCH`, default ports, config
  paths) so the same diagnosis maps onto whichever client you run.
- **`diagnose.sh`** — a **read-only** diagnostic collector. It auto-detects the
  running client and its config dir, identifies who owns the default route,
  tells real-network vs full-tunnel apart, finds system-proxy residue / dead
  ports, shows fake-ip DNS state, runs an 8-shot stability loop, and tests mail
  TLS handshakes.

## Usage

```bash
bash diagnose.sh          # full read-only collection (auto-detects client)
bash diagnose.sh quick    # skip the slower stability / handshake probes
PROXY_IP=<your-server-ip> bash diagnose.sh   # also check the route to your proxy server
```

As a Claude Code / agent skill, drop the folder into your skills directory
(e.g. `~/.claude/skills/proxy-doctor`) and it activates on proxy-related
questions.

## Design principles

1. **Identify the client first.** Don't assume; ask or auto-detect.
2. **Network-first.** Re-test on a different network before touching config.
3. **Read-only first.** Never change settings or delete files before confirming.
4. **Back up before editing; move deletions to Trash, never the iCloud sync dir.**
5. **Question your own "certain" conclusions** with an experiment that can
   actually falsify them.

## License

MIT — see [LICENSE](LICENSE).
