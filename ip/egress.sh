#!/usr/bin/env bash
# 出口检测:请求各站的 /cdn-cgi/trace,看这台机器访问它们时的出口 IP / 国家 / 机房。
# 用法:
#   bash egress.sh          默认(系统选路)
#   bash egress.sh -4       强制 IPv4
#   bash egress.sh -6       强制 IPv6
#   curl -fsSL <托管地址>/egress.sh | bash -s -- -4
# 代理:curl 认 https_proxy / ALL_PROXY,想测代理出口就先 export。

fam=""
case "${1:-}" in -4|-6) fam="$1" ;; esac

if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'; else G=; R=; D=; N=; fi

TARGETS="Cloudflare|www.cloudflare.com
Claude|claude.ai
ChatGPT|chatgpt.com
OpenAI|openai.com
OpenAI-Platform|platform.openai.com
Perplexity|www.perplexity.ai"

printf '%-16s %-40s %-4s %-5s %s\n' 目标 出口IP loc colo 耗时
printf '%s\n' "------------------------------------------------------------------------------"

ips=""
while IFS='|' read -r name host; do
  [ -z "$name" ] && continue
  out=$(curl -s $fam --max-time 8 -w '\n%{time_total}' "https://$host/cdn-cgi/trace" 2>/dev/null)
  t=$(printf '%s' "$out" | tail -n1)
  body=$(printf '%s' "$out" | sed '$d')
  ip=$(printf '%s\n' "$body" | sed -n 's/^ip=//p')
  loc=$(printf '%s\n' "$body" | sed -n 's/^loc=//p')
  colo=$(printf '%s\n' "$body" | sed -n 's/^colo=//p')
  ms=$(awk -v s="${t:-0}" 'BEGIN{printf "%d", s*1000}')
  if [ -n "$ip" ]; then
    printf '%-16s %s%-40s%s %-4s %-5s %s%s ms%s\n' "$name" "$G" "$ip" "$N" "$loc" "$colo" "$D" "$ms" "$N"
    ips="$ips $ip"
  else
    printf '%-16s %s%-40s%s %-4s %-5s %s%s ms%s\n' "$name" "$R" "失败(不通/被拦/无 trace)" "$N" - - "$D" "$ms" "$N"
  fi
done <<EOF
$TARGETS
EOF

echo
# 按协议族分开比:同一台机器 v4/v6 各有一个出口很正常(双栈),不算不一致
n4=$(printf '%s\n' $ips | grep -v : | sort -u | grep -c .)
n6=$(printf '%s\n' $ips | grep : | sort -u | grep -c .)
if [ "$n4" -gt 1 ] || [ "$n6" -gt 1 ]; then
  echo "${R}注意:同一协议族下出口 IP 不一致(v4 $n4 个 / v6 $n6 个),分流把它们送到了不同出口${N}"
elif [ "$n4" -eq 1 ] && [ "$n6" -eq 1 ]; then
  echo "${G}出口一致(双栈:v4 一个、v6 一个;用 -4 / -6 可分别测)${N}"
elif [ "$((n4 + n6))" -eq 1 ]; then
  echo "${G}所有目标出口一致${N}"
fi
