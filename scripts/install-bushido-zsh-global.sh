#!/usr/bin/env bash
set -euo pipefail

# install-bushido-zsh-global.sh
# Instala em /opt/bushido e ativa globalmente para Zsh (sem quebrar shells não-interativos)

TS="$(date +%Y%m%d_%H%M%S)"
PREFIX="/opt/bushido"
ZSHRC="/etc/zsh/zshrc"
ZPROFILE="/etc/zsh/zprofile"

if [[ $EUID -ne 0 ]]; then
  echo "❌ Rode como root: sudo bash install-bushido-zsh-global.sh" >&2
  exit 1
fi

mkdir -p "$PREFIX" /etc/zsh

backup() { [[ -f "$1" ]] && cp -v "$1" "$1.backup.$TS" || true; }

backup "$PREFIX/banner.sh"
backup "$PREFIX/sysinfo.sh"
backup "$PREFIX/welcome.zsh"
backup "$ZSHRC"
backup "$ZPROFILE"

# ----------------- banner.sh -----------------
cat > "$PREFIX/banner.sh" <<'BANNER'
#!/usr/bin/env bash
set -euo pipefail

printf "\033[0;36m"

TERM_COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
BOX_WIDTH=$TERM_COLS
(( BOX_WIDTH > 100 )) && BOX_WIDTH=100
(( BOX_WIDTH < 72 )) && BOX_WIDTH=72
INNER=$(( BOX_WIDTH - 2 ))

border_top()    { printf "╔"; printf "%${INNER}s" | tr " " "═"; printf "╗\n"; }
border_bottom() { printf "╚"; printf "%${INNER}s" | tr " " "═"; printf "╝\n"; }
empty_line()    { printf "║%*s║\n" "$INNER" ""; }

pad_line() {
  local s="$1"
  local len
  len=$(printf '%s' "$s" | wc -m)
  if (( len > INNER )); then
    s=$(printf '%s' "$s" | cut -c1-"$INNER")
    len=$(printf '%s' "$s" | wc -m)
  fi
  local left=$(( (INNER - len) / 2 ))
  local right=$(( INNER - len - left ))
  printf "║%*s%s%*s║\n" "$left" "" "$s" "$right" ""
}

mapfile -t LINES << 'LINES'
▀█████████▄  ███    █▄     ▄████████    ▄█    █▄
  ███    ███ ███    ███   ███    ███   ███    ███
  ███    ███ ███    ███   ███    █▀    ███    ███
 ▄███▄▄▄██▀  ███    ███   ███         ▄███▄▄▄▄███▄▄
▀▀███▀▀▀██▄  ███    ███ ▀███████████ ▀▀███▀▀▀▀███▀
  ███    ██▄ ███    ███          ███   ███    ███
  ███    ███ ███    ███    ▄█    ███   ███    ███
▄█████████▀  ████████▀   ▄████████▀    ███    █▀

🏮 THE WARRIOR'S PATH • 武士道 🏮
Honor Code: 義 • 勇 • 仁 • 礼 • 誠 • 名誉 • 忠義
LINES

border_top
empty_line
for line in "${LINES[@]}"; do
  pad_line "$line"
done
empty_line
border_bottom

printf "\033[0m\n"
BANNER

# ----------------- sysinfo.sh (robusto) -----------------
cat > "$PREFIX/sysinfo.sh" <<'SYSINFO'
#!/usr/bin/env bash
set -euo pipefail

DIM="\033[2m"; RESET="\033[0m"
have() { command -v "$1" >/dev/null 2>&1; }

CORES="$(nproc 2>/dev/null || echo "-")"
READ_LOAD="$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null || echo "- - -")"
UPTIME_H="$(uptime -p 2>/dev/null | sed 's/^up //;s/minutes/min/;s/minute/min/;s/hours/h/;s/hour/h/;s/days/d/' || echo "-")"

human_bytes() { awk -v b="${1:-0}" 'BEGIN{ split("B KiB MiB GiB TiB",u);
  i=1; while (b>=1024 && i<5){ b/=1024; i++ } printf("%.1f%s", b, u[i]) }'; }
human_k() { awk -v k="${1:-0}" 'BEGIN{ b=k*1024; split("B KiB MiB GiB TiB",u);
  i=1; while (b>=1024 && i<5){ b/=1024; i++ } printf("%.1f%s", b, u[i]) }'; }
mem_kb() { awk -v key="$1" '$1==key":"{print $2; f=1} END{if(!f)print 0}' /proc/meminfo 2>/dev/null; }

MT_KB=$(mem_kb MemTotal)
MA_KB=$(mem_kb MemAvailable)
USED_KB=$(( MT_KB - MA_KB ))
PCT_RAM=$(awk -v u="$USED_KB" -v t="$MT_KB" 'BEGIN{ if(t>0){printf("%.1f",(u/t)*100)}else{print "0.0"} }')

RAM_TOTAL_H="$(human_k "$MT_KB")"
RAM_USED_H="$(human_k "$USED_KB")"

CG_NOTE=""
if [ -r /sys/fs/cgroup/memory.max ] 2>/dev/null; then
  CG_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "max")
  if [ "$CG_MAX" != "max" ]; then
    CG_CUR=$(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo 0)
    CG_PCT=$(awk -v c="$CG_CUR" -v m="$CG_MAX" 'BEGIN{ if(m>0){printf("%.1f",(c/m)*100)}else{print "0.0"} }')
    CG_NOTE=" | cgroup cap: $(human_bytes "$CG_CUR") / $(human_bytes "$CG_MAX") (${CG_PCT}%)"
  fi
fi

if have df; then
  read -r _ SIZE USED _ PCT _ < <(df -kP / | awk 'NR==2{print $1,$2,$3,$4,$5,$6}')
  DISK_TOTAL_H="$(human_k "$SIZE")"
  DISK_USED_H="$(human_k "$USED")"
  DISK_PCT="$PCT"
else
  DISK_TOTAL_H="-"; DISK_USED_H="-"; DISK_PCT="-"
fi

if [ -r /etc/os-release ]; then
  . /etc/os-release
  OS_NAME="${PRETTY_NAME:-${NAME:-"-"}}"
else
  OS_NAME="$(lsb_release -ds 2>/dev/null || echo "-")"
fi
KERNEL="$(uname -sr 2>/dev/null || echo "-")"

IP_ADDRS="$(hostname -I 2>/dev/null | xargs || echo "-")"
if have ss; then CONN_EST="$(ss -H state established 2>/dev/null | wc -l | awk '{print $1}')"; else CONN_EST="-"; fi

echo -e "${DIM}"
printf "🖥️  CPU & Load: %s cores | %s\n" "${CORES:--}" "${READ_LOAD:--}"
printf "⏱️  Uptime: %s\n" "${UPTIME_H:--}"
printf "🧠 RAM: %s / %s (%s%%)%s\n" "${RAM_USED_H:--}" "${RAM_TOTAL_H:--}" "${PCT_RAM:--}" "${CG_NOTE}"
printf "💾 Disk (/): %s / %s (%s)\n" "${DISK_USED_H:--}" "${DISK_TOTAL_H:--}" "${DISK_PCT:--}"
printf "🐧 OS: %s | Kernel: %s\n" "${OS_NAME:--}" "${KERNEL:--}"
printf "🌐 Net: %s | Conns(estab): %s\n" "${IP_ADDRS:--}" "${CONN_EST:--}"
echo -e "${RESET}"
SYSINFO

# ----------------- welcome.zsh (guarda + anti-dup) -----------------
cat > "$PREFIX/welcome.zsh" <<'WELCOMEZ'
# Zsh global welcome — só em terminal interativo (TTY) e 1x por sessão
[[ -o interactive ]] || return 0
[[ -t 1 ]] || return 0
[[ -n "${BUSHIDO_NO_BANNER:-}" ]] && return 0
[[ -n "${BUSHIDO_ALREADY_SHOWN:-}" ]] && return 0
export BUSHIDO_ALREADY_SHOWN=1

if command -v bash >/dev/null 2>&1; then
  [[ -x /opt/bushido/banner.sh ]] && bash /opt/bushido/banner.sh || true
  [[ -x /opt/bushido/sysinfo.sh ]] && bash /opt/bushido/sysinfo.sh || true
fi
WELCOMEZ

chmod 0755 "$PREFIX/banner.sh" "$PREFIX/sysinfo.sh"
chmod 0644 "$PREFIX/welcome.zsh"
chown -R root:root "$PREFIX"

# ----------------- injeta no /etc/zsh/zshrc e /etc/zsh/zprofile -----------------
inject_block() {
  local target="$1"
  local marker="BUSHIDO_GLOBAL_WELCOME"
  touch "$target"

  if grep -q "$marker" "$target" 2>/dev/null; then
    return 0
  fi

  cat >> "$target" <<'RC'

# BUSHIDO_GLOBAL_WELCOME (do not remove marker)
# Mostra banner + sysinfo (somente interativo + TTY). Kill-switch: export BUSHIDO_NO_BANNER=1
if [ -f /opt/bushido/welcome.zsh ]; then
  . /opt/bushido/welcome.zsh
fi
RC
}

inject_block "$ZSHRC"
inject_block "$ZPROFILE"

echo "✅ Instalado globalmente para Zsh:"
echo "  - /opt/bushido/*"
echo "  - hook em: $ZSHRC e $ZPROFILE"
echo "Desativar por sessão: export BUSHIDO_NO_BANNER=1"
