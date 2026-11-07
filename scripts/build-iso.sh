#!/usr/bin/env bash
# Build ISO Islet bằng archiso, chạy trong container Arch (máy chủ không cần là Arch).
#   ./scripts/build-iso.sh        → out/islet-YYYY.MM.DD-x86_64.iso
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"
PROFILE="$OUT/profile"
CACHE="$OUT/cache"

mkdir -p "$OUT" "$CACHE/pkg" "$CACHE/fonts"

echo "==> Chuẩn bị profile"
rm -rf "$PROFILE"
cp -a "$ROOT/iso/islet" "$PROFILE"
AIR="$PROFILE/airootfs"

# Islet shell + cấu hình Hyprland
mkdir -p "$AIR/usr/share/islet" "$AIR/usr/share/pixmaps"
cp -a "$ROOT/shell" "$AIR/usr/share/islet/shell"
cp -a "$ROOT/hypr" "$AIR/usr/share/islet/hypr"
cp -a "$ROOT/theme/wallpapers" "$AIR/usr/share/islet/wallpapers"     # hình nền riêng (scripts/make-wallpapers.py)
cp "$ROOT/hypr/hyprland.lua" "$AIR/home/islet/.config/hypr/hyprland.lua"
chmod 644 "$AIR/home/islet/.config/hypr/hyprland.lua"

# Icon: sinh lại từ scripts/make-icons.py, cài bộ "Islet" cho GTK / Nautilus
python3 "$ROOT/scripts/make-icons.py" >/dev/null
mkdir -p "$AIR/usr/share/icons"
cp -a "$ROOT/theme/icons/Islet" "$AIR/usr/share/icons/Islet"
cp -a "$ROOT/theme/cursors/Islet-Cursors" "$AIR/usr/share/icons/Islet-Cursors"     # con trỏ chuột (scripts/make-cursors.py)
# Màn hình khởi động Plymouth
rm -rf "$AIR/usr/share/plymouth/themes/islet"; mkdir -p "$AIR/usr/share/plymouth/themes"
cp -a "$ROOT/theme/plymouth/islet" "$AIR/usr/share/plymouth/themes/islet"
cp "$ROOT/shell/assets/apps/islet.svg" "$AIR/usr/share/pixmaps/islet-app.svg"

# Theme Firefox: nút cửa sổ 🔴🟡🟢 (userChrome.css) + profile tạo sẵn dùng theme đó
mkdir -p "$AIR/usr/share/islet/firefox" "$AIR/home/islet/.config/mozilla/firefox/islet.default/chrome"
cp "$ROOT/theme/firefox/userChrome.css" "$AIR/usr/share/islet/firefox/userChrome.css"
cp "$ROOT/theme/firefox/userChrome.css" "$AIR/home/islet/.config/mozilla/firefox/islet.default/chrome/userChrome.css"
echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' \
    > "$AIR/home/islet/.config/mozilla/firefox/islet.default/user.js"

# Theme GTK: nút cửa sổ 🔴🟡🟢 bên trái
mkdir -p "$AIR/home/islet/.config/gtk-4.0" "$AIR/home/islet/.config/gtk-3.0"
cp "$ROOT/theme/gtk/gtk4.css" "$AIR/home/islet/.config/gtk-4.0/gtk.css"
cp "$ROOT/theme/gtk/gtk3.css" "$AIR/home/islet/.config/gtk-3.0/gtk.css"

# Logo
cp "$ROOT/branding/islet-mark-dark-bg.svg" "$AIR/usr/share/pixmaps/islet.svg"
cp "$ROOT/branding/islet-mark-256.png" "$AIR/usr/share/pixmaps/islet.png"

# Font Be Vietnam Pro (Google Fonts, giấy phép OFL), tải một lần rồi dùng lại
FONT_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro"
for w in Light Regular Medium SemiBold Bold; do
    f="BeVietnamPro-$w.ttf"
    [ -s "$CACHE/fonts/$f" ] || curl -fsSL "$FONT_URL/$f" -o "$CACHE/fonts/$f"
done
[ -s "$CACHE/fonts/OFL.txt" ] || curl -fsSL "$FONT_URL/OFL.txt" -o "$CACHE/fonts/OFL.txt"
mkdir -p "$AIR/usr/share/fonts/be-vietnam-pro"
cp "$CACHE/fonts/"*.ttf "$CACHE/fonts/OFL.txt" "$AIR/usr/share/fonts/be-vietnam-pro/"

# Chế độ dev: cho phép SSH vào máy ảo bằng key tạm (out/dev_key) để đọc log.
if [ "${ISLET_DEV:-0}" = 1 ]; then
    [ -f "$OUT/dev_key" ] || ssh-keygen -q -t ed25519 -N "" -C islet-dev -f "$OUT/dev_key"
    mkdir -p "$AIR/home/islet/.ssh"
    cp "$OUT/dev_key.pub" "$AIR/home/islet/.ssh/authorized_keys"
    cat >> "$PROFILE/profiledef.sh" <<'E'
file_permissions+=(
  ["/home/islet/.ssh"]="1000:1000:700"
  ["/home/islet/.ssh/authorized_keys"]="1000:1000:600"
)
E
    echo "    (dev) SSH: ssh -i out/dev_key -p 2222 islet@localhost"
else
    # Bản phát hành: không mở SSH (archiso bật sẵn sshd + cho root đăng nhập bằng mật khẩu)
    rm -f "$AIR/etc/systemd/system/multi-user.target.wants/sshd.service" \
          "$AIR/etc/ssh/sshd_config.d/10-archiso.conf"
fi

echo "==> Build ISO trong container archlinux (lần đầu mất 10–20 phút)"
docker run --rm --privileged \
    -v "$OUT:/out" \
    -v "$CACHE/pkg:/var/cache/pacman/pkg" \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    archlinux:latest bash -euo pipefail -c '
        # Mirror gần Việt Nam; dự phòng bằng mirror toàn cầu.
        ML=/etc/pacman.d/mirrorlist
        if curl -fsS --max-time 20 "https://archlinux.org/mirrorlist/?country=VN&country=SG&country=JP&country=HK&protocol=https&use_mirror_status=on" -o /tmp/ml \
            && grep -q "^#Server" /tmp/ml; then
            sed "s/^#Server/Server/" /tmp/ml > $ML
        fi
        cat >> $ML <<EOF
Server = https://mirror.bizflycloud.vn/archlinux/\$repo/os/\$arch
Server = https://download.nus.edu.sg/mirror/archlinux/\$repo/os/\$arch
Server = https://mirrors.cat.net/archlinux/\$repo/os/\$arch
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch
EOF
        echo "Mirror: $(grep -c ^Server $ML) máy chủ"
        sed -i "s/^#\?ParallelDownloads.*/ParallelDownloads = 8/" /etc/pacman.conf

        pacman -Syu --noconfirm --needed archiso imagemagick librsvg >/dev/null

        # Màn hình boot BIOS (syslinux) mang logo Islet
        magick -size 640x480 xc:"#0A0A14" \
            \( -background none /out/profile/airootfs/usr/share/pixmaps/islet.svg -resize 180x180 \) \
            -gravity center -geometry +0-40 -composite /out/profile/syslinux/splash.png

        rm -rf /out/work /out/build
        mkarchiso -v -r -w /out/work -o /out/build /out/profile
        # Đổi tên sau khi xong để máy ảo đang chạy ISO cũ không bị ảnh hưởng.
        for f in /out/build/*.iso; do mv -f "$f" /out/; chown "$HOST_UID:$HOST_GID" "/out/${f##*/}"; done
        rmdir /out/build
    '

ls -lh "$OUT"/*.iso
