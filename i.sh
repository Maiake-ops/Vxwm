#!/bin/bash
# vxwm kitty rice (stable edition)
# Supports: Arch, Void, Gentoo

set -euo pipefail

# ─── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
CYN='\033[0;36m'
RST='\033[0m'

info()  { echo -e "${CYN}[*]${RST} $*"; }
ok()    { echo -e "${GRN}[✓]${RST} $*"; }
warn()  { echo -e "${YLW}[!]${RST} $*"; }
die()   { echo -e "${RED}[✗]${RST} $*" >&2; exit 1; }

# ─── Detect distro ─────────────────────────────────────────────────────────────
detect_distro() {
    if   command -v pacman      &>/dev/null; then echo "arch"
    elif command -v xbps-install &>/dev/null; then echo "void"
    elif command -v emerge       &>/dev/null; then echo "gentoo"
    else die "Unsupported distro (needs pacman, xbps-install, or emerge)"
    fi
}

# ─── Package install ───────────────────────────────────────────────────────────
install_arch() {
    sudo pacman -Sy --needed --noconfirm \
        xorg-server xorg-xinit xorg-xsetroot \
        picom kitty feh rofi polybar btop gnuplot curl
}

install_void() {
    sudo xbps-install -Sy \
        xorg xinit xsetroot \
        picom kitty feh rofi polybar btop gnuplot curl
}

install_gentoo() {
    sudo emerge --ask=n \
        x11-base/xorg-server \
        x11-apps/xinit \
        x11-apps/xsetroot \
        x11-misc/picom \
        x11-terms/kitty \
        x11-misc/feh \
        x11-misc/rofi \
        x11-misc/polybar \
        sys-process/btop \
        sci-visualization/gnuplot \
        net-misc/curl
}

# ─── Config: picom ─────────────────────────────────────────────────────────────
write_picom_conf() {
    local dest="$HOME/.config/picom/picom.conf"
    [[ -f "$dest" ]] && { warn "Skipping picom.conf (already exists, use --force to overwrite)"; return; }
    mkdir -p "$(dirname "$dest")"
    cat > "$dest" << 'EOF'
backend = "glx";
vsync = true;
corner-radius = 12;
round-borders = 1;

opacity-rule = [
  "90:class_g = 'kitty'"
];

blur: {
  method = "dual_kawase";
  strength = 6;
};
EOF
    ok "picom.conf written"
}

# ─── Config: kitty ─────────────────────────────────────────────────────────────
write_kitty_conf() {
    local dest="$HOME/.config/kitty/kitty.conf"
    [[ -f "$dest" ]] && { warn "Skipping kitty.conf (already exists, use --force to overwrite)"; return; }
    mkdir -p "$(dirname "$dest")"
    cat > "$dest" << 'EOF'
background_opacity    0.9
window_padding_width  10
font_size             11.0

foreground            #cdd6f4
background            #0f111a

cursor_shape          block
cursor_blink_interval 0.5
EOF
    ok "kitty.conf written"
}

# ─── Wallpaper ─────────────────────────────────────────────────────────────────
fetch_wallpaper() {
    local wall="$HOME/.wallpaper.jpg"
    if [[ -f "$wall" ]]; then
        warn "Wallpaper already exists at $wall, skipping download"
        return
    fi
    info "Downloading wallpaper..."
    if curl -fsSL -o "$wall" "https://picsum.photos/1920/1080"; then
        ok "Wallpaper saved to $wall"
    else
        warn "Wallpaper download failed — set one manually with: feh --bg-scale <path>"
    fi
}

# ─── .xinitrc ──────────────────────────────────────────────────────────────────
write_xinitrc() {
    local dest="$HOME/.xinitrc"
    if [[ -f "$dest" && "${FORCE:-0}" != "1" ]]; then
        warn "Skipping .xinitrc (already exists, use --force to overwrite)"
        return
    fi

    cat > "$dest" << 'EOF'
#!/bin/sh

# Status bar: clock + load average
while true; do
    xsetroot -name "$(date '+%a %d %b  %H:%M:%S')  |  load: $(cut -d' ' -f1-3 /proc/loadavg)"
    sleep 1
done &

# Compositor
picom --config "$HOME/.config/picom/picom.conf" &

# Wallpaper
feh --bg-scale "$HOME/.wallpaper.jpg" &

# Launch WM
exec vxwm
EOF

    chmod +x "$dest"
    ok ".xinitrc written"
}

# ─── Arg parsing ───────────────────────────────────────────────────────────────
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--force]"
            echo "  --force   Overwrite existing config files"
            exit 0
            ;;
        *) die "Unknown argument: $arg" ;;
    esac
done

export FORCE

# ─── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYN}  vxwm kitty rice — stable edition${RST}"
echo "  ────────────────────────────────"
echo ""

DISTRO="$(detect_distro)"
info "Detected distro: $DISTRO"

info "Installing packages..."
case "$DISTRO" in
    arch)   install_arch   ;;
    void)   install_void   ;;
    gentoo) install_gentoo ;;
esac
ok "Packages installed"

write_picom_conf
write_kitty_conf
fetch_wallpaper
write_xinitrc

echo ""
ok "Setup complete."
echo ""
echo -e "  ${GRN}Next step:${RST}  startx"
echo ""
echo "  Keybinds (vxwm defaults):"
echo "    Super+Enter   kitty"
echo "    Super+D       rofi"
echo "    Super+Space   toggle float"
echo ""

