#!/usr/bin/env bash
# Build các gói Islet thành kho pacman [islet] (đã ký) ở out/repo — chạy trong container Arch.
#   ./scripts/build-packages.sh                 kho cục bộ (build-iso.sh dùng)
#   ISLET_RELEASE=1 ./scripts/build-packages.sh bắt buộc cây git sạch (cho scripts/release-repo.sh)
#
# Gói:  islet (gộp) · islet-shell · islet-tools · islet-themes · islet-keyring
# Phiên bản mỗi gói = 0.1.r<số commit đụng tới thư mục của gói đó> → gói nào không đổi thì không
# bắt máy người dùng tải lại.  Khoá ký: ~/.local/share/islet-release/gnupg (KHÔNG nằm trong repo).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"
REPO="$OUT/repo"
STAGE="$OUT/pkgbuild"
CACHE="$OUT/cache"
export GNUPGHOME="${ISLET_GNUPGHOME:-$HOME/.local/share/islet-release/gnupg}"
KEY="$(cut -d: -f1 "$ROOT/packaging/keyring/islet-trusted")"

if [ "${ISLET_RELEASE:-0}" = 1 ] && [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
    echo "Cây git chưa sạch — commit trước khi phát hành." >&2; exit 1
fi
gpg --list-secret-keys "$KEY" >/dev/null 2>&1 || { echo "Không thấy khoá ký $KEY trong $GNUPGHOME" >&2; exit 1; }

ver() { echo "0.1.r$(git -C "$ROOT" rev-list --count HEAD -- "$@")"; }
# thư mục của từng gói (phiên bản = số commit đụng tới chúng)
declare -A PATHS=(
    [islet-shell]="shell hypr tools/applications packaging/islet-shell"
    [islet-tools]="tools/bin tools/systemd tools/libalpm tools/initcpio packaging/islet-tools"
    [islet-themes]="theme branding shell/assets/apps/islet.svg packaging/islet-themes"
    [islet-keyring]="packaging/keyring packaging/islet-keyring"
    [islet]="packaging/islet"
)
declare -A VER=()
# shellcheck disable=SC2086
for p in "${!PATHS[@]}"; do VER[$p]="$(ver ${PATHS[$p]})"; done

# Font Be Vietnam Pro (Google Fonts, OFL) cho islet-themes — tải một lần
FONTS="$CACHE/fonts"; mkdir -p "$FONTS" "$CACHE/pkg"
FONT_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro"
for w in Light Regular Medium SemiBold Bold; do
    [ -s "$FONTS/BeVietnamPro-$w.ttf" ] || curl -fsSL "$FONT_URL/BeVietnamPro-$w.ttf" -o "$FONTS/BeVietnamPro-$w.ttf"
done
[ -s "$FONTS/OFL.txt" ] || curl -fsSL "$FONT_URL/OFL.txt" -o "$FONTS/OFL.txt"

echo "==> Chuẩn bị PKGBUILD"
rm -rf "$STAGE"; mkdir -p "$STAGE" "$REPO"
rm -f "$REPO"/*.pkg.tar.* "$REPO"/islet.db* "$REPO"/islet.files*
for p in "${!VER[@]}"; do
    cp -r "$ROOT/packaging/$p" "$STAGE/$p"
    sed -i "s/@VER@/${VER[$p]}/" "$STAGE/$p/PKGBUILD"
    printf '    %-14s %s\n' "$p" "${VER[$p]}"
done

echo "==> makepkg (container archlinux)"
docker run --rm -v "$ROOT:/src:ro" -v "$STAGE:/build" -v "$REPO:/repo" -v "$FONTS:/fonts:ro" \
    -v "$CACHE/pkg:/var/cache/pacman/pkg" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    archlinux:latest bash -euo pipefail -c '
        pacman -Sy --noconfirm --needed fakeroot binutils >/dev/null
        sed -i -E "s/^OPTIONS=\((.*)\)/OPTIONS=(\1 !debug !strip)/" /etc/makepkg.conf
        useradd -m builder
        chown -R builder /build /repo
        for d in /build/*/; do
            su builder -c "cd $d && ISLET_SRC=/src ISLET_FONTS=/fonts PKGDEST=/repo makepkg -f -d --noconfirm --nocheck >/dev/null"
        done
        chown -R "$HOST_UID:$HOST_GID" /build /repo
    '

echo "==> Ký gói"
for f in "$REPO"/*.pkg.tar.zst; do
    gpg --batch --yes --quiet --detach-sign --no-armor -u "$KEY" -o "$f.sig" "$f"
done

echo "==> repo-add"
docker run --rm -v "$REPO:/repo" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" archlinux:latest bash -euo pipefail -c '
    cd /repo && repo-add -q --include-sigs islet.db.tar.gz *.pkg.tar.zst
    chown "$HOST_UID:$HOST_GID" /repo/*
'
# GitHub Releases không giữ symlink → thay islet.db / islet.files bằng bản sao, rồi ký kho
for db in islet.db islet.files; do
    cp --remove-destination "$REPO/$db.tar.gz" "$REPO/$db"
    gpg --batch --yes --quiet --detach-sign --no-armor -u "$KEY" -o "$REPO/$db.tar.gz.sig" "$REPO/$db.tar.gz"
    cp "$REPO/$db.tar.gz.sig" "$REPO/$db.sig"
done
# Nhật ký thay đổi cho Cài đặt › Updates: mỗi commit gần đây, gói nào nó đổi và phiên bản gói đó SAU commit ấy
# → máy đang ở 0.1.r250 lên 0.1.r262 thì hiện các commit có số trong (250, 262].
echo "==> islet-changes.json"
for p in "${!PATHS[@]}"; do printf '%s\t%s\n' "$p" "${PATHS[$p]}"; done | python3 - "$ROOT" "$REPO/islet-changes.json" <<'PY'
import json, subprocess, sys
root, out = sys.argv[1], sys.argv[2]
paths = dict(l.rstrip("\n").split("\t", 1) for l in sys.stdin if l.strip())
git = lambda *a: subprocess.run(["git", "-C", root, *a], capture_output=True, text=True, check=True).stdout
changes = {}
for pkg, ps in paths.items():
    # mọi commit đụng tới gói, cũ → mới; vị trí trong danh sách = phiên bản của gói sau commit đó
    hs = git("rev-list", "--reverse", "HEAD", "--", *ps.split()).split()
    for i, h in enumerate(hs[-80:], start=len(hs) - min(80, len(hs)) + 1):
        changes.setdefault(h, {})[pkg] = i
items = []
for h, revs in changes.items():
    t, subj, body = git("show", "-s", "--format=%ct%x00%s%x00%b", h).split("\0", 2)
    para = body.strip().split("\n\n")[0].strip()
    items.append({"commit": h[:10], "time": int(t), "subject": subj.strip(),
                  "detail": "" if para.startswith("Co-Authored-By") else " ".join(para.split())[:400], "revs": revs})
items.sort(key=lambda x: -x["time"])
json.dump({"changes": items[:120]}, open(out, "w"), ensure_ascii=False, indent=0)
print(f"    {min(len(items), 120)} changes")
PY
ls -lh "$REPO"
