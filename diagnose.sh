#!/usr/bin/env bash
# proxy-doctor 只读诊断采集器（macOS / Loon）
# 只读：只用 networksetup -get*、scutil、lsof、curl、openssl、traceroute，绝不修改任何设置。
# 用法：bash diagnose.sh            # 全量采集
#       bash diagnose.sh quick      # 跳过耗时的稳定性/握手探测
set +e
QUICK="${1:-}"
sec() { printf '\n\033[1m===== %s =====\033[0m\n' "$*"; }

sec "0) 时间 / 系统（SSL 校验依赖系统时间是否正确）"
date; sw_vers 2>/dev/null
echo "(时间明显不对会直接导致 TLS 证书校验失败；getusingnetworktime 需管理员权限，故略)"

sec "1) 识别代理客户端（先确定是哪个软件，再对症下药）"
ps aux | grep -iE "loon|shadowrocket|clash|mihomo|surge|stash|v2ray|xray|sing-box|trojan|quantumult|wireguard|openvpn" \
  | grep -v grep | awk '{print $2, $11, $12, $13}' || echo "  (无运行中的已知客户端)"
echo "-- 命中的客户端 + 配置目录（用于定位要改哪个文件）："
det=0
chk() { # $1=关键词 $2=展示名 $3...=候选配置路径
  local kw="$1" name="$2"; shift 2
  if pgrep -ifq "$kw" 2>/dev/null; then
    det=1; echo "  [$name] 运行中"
    for p in "$@"; do [ -e "$p" ] && echo "      配置: $p"; done
  fi
}
chk "Loon"          "Loon (.lcf, INI类)"        "$HOME/Library/Application Support/com.loon.Loon"
chk "nssurge|Surge" "Surge (.conf, INI类)"      "$HOME/Library/Application Support/com.nssurge.surge-mac"
chk "ClashX|mihomo|clash" "Clash/Mihomo (.yaml)" "$HOME/.config/clash" "$HOME/.config/mihomo" "$HOME/Library/Application Support/ClashX" "$HOME/Library/Application Support/com.metacubex.ClashX.Meta"
chk "Stash"         "Stash (Clash核, .yaml)"    "$HOME/Library/Application Support/com.gozap.stash"
chk "sing-box|sfa|sfm" "sing-box (.json)"       "$HOME/Library/Application Support/sing-box"
chk "Shadowrocket"  "Shadowrocket (.conf, Surge类)" "$HOME/Library/Mobile Documents/iCloud~com~liguangming~Shadowrocket/Documents"
[ "$det" = 0 ] && echo "  (没识别到——若客户端只装在手机/用 TUN 扩展跑，按 §2 看默认路由网卡名反推)"

sec "2) 活动隧道网卡 + 默认路由归属（谁在接管上网）"
ifconfig -l | tr ' ' '\n' | grep -E "utun|en0"
echo "-- 默认路由："; route -n get 1.1.1.1 2>/dev/null | grep -E "interface|gateway"
PROXY_IP="${PROXY_IP:-203.0.113.1}"  # 占位示例；用 PROXY_IP=你的服务器IP 覆盖
echo "-- 到代理服务器($PROXY_IP)的路由："; route -n get "$PROXY_IP" 2>/dev/null | grep -E "interface|gateway"

sec "3) 全隧道判定：en0-bind 是否真能绕过隧道（看第一跳）"
echo "(第一跳是真实网关如 192.168.x/10.x => 绕过成功；是 198.19.x/Loon 地址 => 全隧道，'raw' 测试不可信)"
traceroute -n -i en0 -w 1 -q 1 -m 3 1.1.1.1 2>/dev/null | head -4

sec "4) 系统代理残留（换软件后最常见的冲突源）"
echo "-- scutil --proxy："; scutil --proxy 2>/dev/null | grep -iE "Enable|Proxy|Port" | head
for svc in $(networksetup -listallnetworkservices 2>/dev/null | tail -n +2); do
  for p in webproxy securewebproxy socksfirewallproxy; do
    out=$(networksetup -get${p} "$svc" 2>/dev/null)
    echo "$out" | grep -qi "Enabled: Yes" && echo "  [$svc] $p: $(echo "$out" | tr '\n' ' ')"
  done
done
echo "-- 死端口监听检查（7221/7222/7890/1080 等若被系统代理指向却无人监听 = 死代理）："
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E ":(7221|7222|7890|7891|1080|1086|1087|6152|6153)\b" || echo "  (这些端口无监听)"

sec "5) shell / git / npm 代理残留"
grep -niE "proxy|1080|7890|7222|6152" ~/.zshrc ~/.zprofile ~/.zshenv ~/.bash_profile ~/.bashrc 2>/dev/null || echo "  shell 配置：无"
env | grep -iE "proxy" || echo "  环境变量：无"
echo "  git http.proxy: $(git config --global --get http.proxy 2>/dev/null || echo 无)"
command -v npm >/dev/null && echo "  npm proxy: $(npm config get proxy 2>/dev/null)"

sec "6) DNS / fake-ip 状态"
scutil --dns 2>/dev/null | grep -i "nameserver" | sort -u | head
echo "(出现 198.19.0.x 之类 = Loon fake-ip 模式正常特征；域名被解析成 198.0.x.x 也属正常占位)"

[ "$QUICK" = "quick" ] && { echo; echo "(quick 模式：跳过稳定性与握手探测)"; exit 0; }

sec "7) 代理稳定性实测（透过当前隧道，8 连发 gstatic/204）"
ok=0; fail=0
for i in 1 2 3 4 5 6 7 8; do
  r=$(curl -s -o /dev/null -w "%{time_appconnect}|%{time_total}|%{http_code}" --connect-timeout 8 --max-time 20 https://www.gstatic.com/generate_204 2>/dev/null)
  code=${r##*|}
  echo "  run$i: tls=$(echo "$r"|cut -d'|' -f1)s total=$(echo "$r"|cut -d'|' -f2)s code=$code"
  [ "$code" = "204" ] && ok=$((ok+1)) || fail=$((fail+1))
done
echo "  >>> 成功 $ok/8，失败 $fail。剧烈抖动(0.5→7,8s)或 >0 失败 = 大概率网络层(校园/企业网 DPI/限速)，先换网络验证。"

sec "8) 邮件 TLS 握手（落到坏节点时邮件 App 报 SSL error 的根因诊断）"
for hp in imap.gmail.com:993 imap.mail.me.com:993; do
  host=${hp%:*}
  echo "-- $hp"
  echo Q | openssl s_client -connect "$hp" -servername "$host" 2>/dev/null </dev/null \
    | grep -iE "subject=|issuer=|Verify return code|no peer certificate" | head -4
  echo "   (拿到 Google Trust Services / Apple Inc. 证书且 Verify return code: 0 = 正常；"
  echo "    'no peer certificate available' = 当前节点连不通该目标，需在 Loon 换入口/节点或加钉死规则)"
done

sec "诊断完成"
echo "解读顺序：先看 §7 稳定性 → §3/§4 排除环境与残留 → §8 针对邮件类。结论写法与修法见 SKILL.md。"
