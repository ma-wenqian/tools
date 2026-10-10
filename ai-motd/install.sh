#!/bin/sh
# 在 SSH 登录时显示 Claude / OpenAI 的可达性和各自的出口(IP / 国家 / CF 机房)。
#
#   安装:   curl -fsSL https://tools.vnkma.com/ai-motd/install.sh | sudo sh
#   卸载:   curl -fsSL https://tools.vnkma.com/ai-motd/install.sh | sudo sh -s -- --uninstall
#   先看再装: curl -fsSLo install.sh https://tools.vnkma.com/ai-motd/install.sh && less install.sh && sudo sh install.sh
#
# 它只做一件事:写入 /etc/update-motd.d/99-ai-status(登录时由 pam_motd 执行)。
# 脚本只读公开接口(api.*/v1/models 不带 key、/cdn-cgi/trace),不改网络、不装软件、不开服务。
# 重复运行安全:内容相同则什么都不做;内容不同会先把旧文件挪到 /var/backups/(不能留在
# update-motd.d 里,pam_motd 会执行目录里每个可执行文件,备份会跟着跑、登录显示两遍)。
set -eu

DIR="${MOTD_DIR:-/etc/update-motd.d}"
DST="$DIR/99-ai-status"
BAK="${BACKUP_DIR:-/var/backups}"

if [ "$(id -u)" -ne 0 ] && [ -z "${MOTD_DIR:-}" ]; then
	echo "需要 root:请用 sudo 运行" >&2
	exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
	if [ -f "$DST" ]; then rm -f "$DST"; echo "已卸载 $DST"; else echo "没装过,无需卸载"; fi
	exit 0
fi

if [ ! -d "$DIR" ]; then
	echo "没有 $DIR:这台机器不是 Debian / Ubuntu 的 pam_motd 风格,不适用" >&2
	exit 1
fi
command -v curl >/dev/null 2>&1 || { echo "需要 curl" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<'PAYLOAD'
#!/bin/sh
# Live AI reachability check shown at SSH login (pam_motd).
# /v1/models without a key: 401 = reachable and region OK, 403 = region blocked.
# Each line also shows the exit (IP, country, CF colo) that host is reached through,
# read from https://<host>/cdn-cgi/trace -- shown only, it does not decide unlocked/blocked.
# Everything runs in parallel, capped at 3s per request, so login is never held up longer.

check() {
	tr=$(mktemp 2>/dev/null) || tr=/dev/null
	curl -s -m 3 "https://$2/cdn-cgi/trace" > "$tr" 2>/dev/null &
	tp=$!
	r=$(curl -s -o /dev/null -m 3 -w '%{http_code} %{time_total}' "https://$2/v1/models" 2>/dev/null)
	wait "$tp"
	code=${r%% *}
	t=$(printf '%.1fs' "${r#* }" 2>/dev/null)
	case "$code" in
		401|200) s="✔ unlocked" ;;
		403) s="✘ blocked (region)" ;;
		000|"") s="✘ unreachable"; t="  -  " ;;
		*) s="? HTTP $code" ;;
	esac
	ip=$(sed -n 's/^ip=//p' "$tr" 2>/dev/null)
	loc=$(sed -n 's/^loc=//p' "$tr" 2>/dev/null)
	colo=$(sed -n 's/^colo=//p' "$tr" 2>/dev/null)
	[ "$tr" = /dev/null ] || rm -f "$tr"
	if [ -n "$ip" ]; then
		x="exit $ip ${loc:--}${colo:+ ($colo)}"
	else
		x="exit ?"
	fi
	printf '  %-7s %-19s %5s  %s  %s\n' "$1" "$2" "$t" "$s" "$x"
}

tmp=$(mktemp -d 2>/dev/null) || exit 0
check Claude api.anthropic.com > "$tmp/1" &
p1=$!
check OpenAI api.openai.com > "$tmp/2" &
p2=$!
wait "$p1" "$p2"

echo
echo "================================= AI access =================================="
cat "$tmp/1" "$tmp/2"
echo "=============================================================================="
echo "  source: tools.vnkma.com/ai-motd  |  github.com/ma-wenqian/tools"
rm -rf "$tmp"
PAYLOAD

if [ -f "$DST" ]; then
	if cmp -s "$tmp" "$DST"; then echo "已是最新,无需改动"; exit 0; fi
	mkdir -p "$BAK"
	cp -p "$DST" "$BAK/99-ai-status.$(date +%Y%m%d-%H%M%S)"
	echo "旧版已备份到 $BAK/"
fi
install -m 755 "$tmp" "$DST"
echo "已安装 $DST —— 下次 SSH 登录就会看到。现在预览:"
echo
sh "$DST"
