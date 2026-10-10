# tools

Small public, dependency-free tools. One directory per tool.
小而独立的公开工具,一个工具一个目录,都不依赖后端。

Hosted copy / 在线版本: <https://tools.vnkma.com/>

| Tool | What it does |
| --- | --- |
| [`ip/`](ip/) | Which exit IP / country does *this network* use to reach Claude, ChatGPT and Cloudflare? Browser page + a shell script for servers. |
| [`ai-motd/`](ai-motd/) | SSH login banner on Debian/Ubuntu: are Claude / OpenAI reachable from this server, and through which exit? |

---

## `ip/` — exit check / 出口检测

**How it works.** It requests `https://<site>/cdn-cgi/trace` for each target. That is a tiny
endpoint answered by Cloudflare's edge, and it reports the IP, country (`loc`) and data
centre (`colo`) Cloudflare sees for you. It does not touch the target's own servers or
your account, and sends no cookies.

**Browser:** open <https://tools.vnkma.com/ip/> (or serve `ip/` yourself, any static server).
It measures the device you open it on.

**Server:**

```sh
curl -fsSL https://tools.vnkma.com/ip/egress.sh | bash
# force IPv4 / IPv6
curl -fsSL https://tools.vnkma.com/ip/egress.sh | bash -s -- -4
curl -fsSL https://tools.vnkma.com/ip/egress.sh | bash -s -- -6
```

`curl` honours `https_proxy` / `ALL_PROXY`, so export one first to test a proxy's exit.

Notes:
- A dual-stack host will often show one IPv4 and one IPv6 exit. That is normal, the summary
  only warns when exits differ *within the same address family*.
- `colo` is the Cloudflare data centre you entered (an airport code), **not** where the IP is registered.
- Don't run it in a tight loop or from cron every few seconds. Cloudflare may rate-limit the IP.
- Reading the script before piping it to a shell is a good habit: it is ~50 lines.

## `ai-motd/` — login banner / 登录提示

```
================================= AI access ==================================
  Claude  api.anthropic.com    0.7s  ✔ unlocked  exit 203.0.113.7 US (LAX)
  OpenAI  api.openai.com       0.7s  ✔ unlocked  exit 203.0.113.7 US (LAX)
==============================================================================
  source: tools.vnkma.com/ai-motd  |  github.com/ma-wenqian/tools
```

`401` from `/v1/models` without a key = reachable and region allowed, `403` = region blocked.
The `exit …` part is read from `/cdn-cgi/trace` and is informational only, it does not
decide the status. Each login adds ~1 s at most (everything runs in parallel, 3 s cap).

It only writes `/etc/update-motd.d/99-ai-status`. No packages, no services, no network changes.

```sh
# install
curl -fsSL https://tools.vnkma.com/ai-motd/install.sh | sudo sh
# uninstall
curl -fsSL https://tools.vnkma.com/ai-motd/install.sh | sudo sh -s -- --uninstall
# or read first, then run
curl -fsSLo install.sh https://tools.vnkma.com/ai-motd/install.sh && less install.sh && sudo sh install.sh
```

Re-running is safe: identical content does nothing; a different existing file is backed up to
`/var/backups/` first (never inside `update-motd.d`, because pam_motd executes **every**
executable file in that directory, a backup there would print the banner twice).

**There is deliberately no auto-update.** The banner runs as root on every login, so a
self-updating copy would let a compromised repo or domain run code as root on every
machine. To update, run the install command again.

## License

MIT for this repository's code, see [`LICENSE`](LICENSE).
The flag font in `ip/fonts/` is third-party (Twemoji, CC-BY 4.0), see [`NOTICE.md`](NOTICE.md).
