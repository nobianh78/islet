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

# Islet (shell, theme, công cụ) là các gói pacman trong kho [islet] — build/ký trước ở out/repo,
# mkarchiso cài từ đó (file:///out/repo). Máy đã cài nhận bản mới qua kho trên GitHub (xem
# scripts/release-repo.sh). Vì thế KHÔNG chép shell/theme thẳng vào airootfs nữa.
[ "${ISLET_SKIP_PKGS:-0}" = 1 ] || "$ROOT/scripts/build-packages.sh"
cat >> "$PROFILE/pacman.conf" <<'E'

[islet]
SigLevel = Required DatabaseRequired
Server = file:///out/repo
E
grep -qx islet "$PROFILE/packages.x86_64" || echo islet >> "$PROFILE/packages.x86_64"
cp "$ROOT/packaging/keyring/islet.gpg" "$ROOT/packaging/keyring/islet-trusted" "$OUT/"      # container build tin khoá Islet (xem bên dưới)

cp "$ROOT/branding/islet-mark-dark-bg.svg" "$PROFILE/islet-splash.svg"     # logo trên màn hình boot BIOS

# Theme Firefox: profile tạo sẵn dùng userChrome.css của Islet (islet-firefox-theme cập nhật mỗi lần đăng nhập)
mkdir -p "$AIR/home/islet/.config/mozilla/firefox/islet.default/chrome"
cp "$ROOT/theme/firefox/userChrome.css" "$AIR/home/islet/.config/mozilla/firefox/islet.default/chrome/userChrome.css"
echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' \
    > "$AIR/home/islet/.config/mozilla/firefox/islet.default/user.js"

# Theme GTK: nút cửa sổ 🔴🟡🟢 bên trái — trỏ tới bản trong gói islet-themes để còn được cập nhật
mkdir -p "$AIR/home/islet/.config/gtk-4.0" "$AIR/home/islet/.config/gtk-3.0"
echo '@import url("file:///usr/share/islet/gtk/gtk4.css");' > "$AIR/home/islet/.config/gtk-4.0/gtk.css"
echo '@import url("file:///usr/share/islet/gtk/gtk3.css");' > "$AIR/home/islet/.config/gtk-3.0/gtk.css"

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
        # kho [islet] cục bộ được ký bằng khoá Islet → keyring của container phải tin khoá đó
        pacman-key --init >/dev/null 2>&1
        pacman-key --add /out/islet.gpg >/dev/null 2>&1
        pacman-key --lsign-key "$(cut -d: -f1 /out/islet-trusted)" >/dev/null 2>&1

        # Màn hình boot BIOS (syslinux) mang logo Islet
        magick -size 640x480 xc:"#0A0A14" \
            \( -background none /out/profile/islet-splash.svg -resize 180x180 \) \
            -gravity center -geometry +0-40 -composite /out/profile/syslinux/splash.png

        rm -rf /out/work /out/build
        mkarchiso -v -r -w /out/work -o /out/build /out/profile
        # Đổi tên sau khi xong để máy ảo đang chạy ISO cũ không bị ảnh hưởng.
        for f in /out/build/*.iso; do mv -f "$f" /out/; chown "$HOST_UID:$HOST_GID" "/out/${f##*/}"; done
        rmdir /out/build
    '

ls -lh "$OUT"/*.iso
