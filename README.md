# Islet

Distro Linux có sẵn Dynamic Island. Nền: Arch Linux + Hyprland + Quickshell.

## Cấu trúc

```
branding/      logo Islet
shell/         Islet shell viết bằng QML (Quickshell)
  shell.qml    điểm vào
  theme/       màu, font, thông số chuyển động
  services/    nhạc (MPRIS), âm lượng (PipeWire), pin (UPower), thông báo
  island/      Dynamic Island
  bar/         thanh trên cùng (logo, workspace, app đang mở, mạng, pin, giờ)
  dock/        dock kính mờ, phóng to theo chuột
  controlcenter/ trung tâm điều khiển (Wi-Fi, Bluetooth, âm lượng, độ sáng, nhạc)
  widgets/     viền sáng cửa sổ, ba chấm trên cửa sổ
  wallpaper/   hình nền động (đốm màu trôi)
  common/      Icon, Glass dùng chung
  assets/      icon
hypr/          cấu hình Hyprland 0.57+ (Lua): animation lò xo, blur, phím tắt
iso/islet/     profile archiso (dựa trên releng): gói, người dùng live, boot
scripts/       build-iso.sh, run-vm.sh, dev.sh, link.sh
```

## Dynamic Island

| Chế độ | Khi nào | Kích thước |
| --- | --- | --- |
| Rảnh | Không có gì | 132×36, hiện đôi mắt mèo, chớp mắt, híp mắt khi rê chuột |
| Nhạc thu gọn | Có trình phát MPRIS | 300×36: ảnh bìa, tên bài, sóng nhạc |
| Trình phát | Bấm vào island hoặc `Super+I` | 440×196: ảnh bìa, tiến trình kéo tua, lùi/phát/tới |
| Âm lượng | Đổi âm lượng | 320×40, hiện 1,6 giây |
| Sạc pin | Cắm sạc | 320×40, số % chạy lên, hiện 2,6 giây |
| Thông báo | Có thông báo mới | 420×84, hiện 5 giây, bấm để tắt |

Khung đổi kích thước bằng lò xo (hơi nảy). Nội dung cũ mờ và nhoè đi rồi nội dung mới hiện ra.

## Build ISO và chạy máy ảo

Cần `docker`, `qemu-system-x86`, `ovmf` (máy chủ là Ubuntu cũng được, archiso chạy trong container Arch).

```bash
./scripts/build-iso.sh    # → out/islet-*.iso
./scripts/run-vm.sh       # boot trong QEMU, tự vào Hyprland + Islet shell
```

Trong máy ảo: `islet-demo` chạy lần lượt các chế độ island,
`Super+I` mở trình phát, `Super+A` mở trung tâm điều khiển, `Super+=` / `Super+-` đổi âm lượng,
`Super+Enter` mở terminal, `Print` / `Shift+Print` chụp màn hình.

Sửa code shell rồi chạy `./scripts/vm-sync.sh` để đẩy vào máy ảo đang chạy (không cần build lại ISO).
`./scripts/vm-sync.sh setup` đẩy thêm config Hyprland, theme kitty. `./scripts/vm-sync.sh log` xem log Quickshell.

`ISLET_DEV=1 ./scripts/build-iso.sh` thêm SSH key tạm để vào máy ảo: `ssh -i out/dev_key -p 2222 islet@localhost`.

## Chạy shell trên máy thật

Cần một phiên **Hyprland**, vì GNOME không hỗ trợ layer-shell nên island không hiện được trên GNOME.

Trên Arch:

```bash
sudo pacman -S hyprland quickshell playerctl libnotify kitty
./scripts/link.sh      # rồi đăng xuất, chọn Hyprland
./scripts/dev.sh       # trong Hyprland: chạy shell từ mã nguồn
./scripts/dev.sh demo  # thử lần lượt các chế độ
```

Trên Ubuntu 26.04: `sudo apt install hyprland playerctl libnotify-bin`. Quickshell chưa có trong apt, phải build từ mã nguồn
(<https://quickshell.org/docs/guide/install-setup/>), hoặc chạy thử trong máy ảo Arch.

Điều khiển từ terminal:

```bash
qs -p shell ipc call island toggle
qs -p shell ipc call island test notif     # notif | volume | battery
```

## Lộ trình

1. [x] Dynamic Island
2. [x] Thanh trên cùng, dock, trung tâm điều khiển, widget đồng hồ
3. [x] Cấu hình Hyprland (Lua), hình nền động, theme kitty
4. [x] Đóng ISO bằng `archiso`, chạy thử trong QEMU
5. [ ] Trình mở ứng dụng (launcher), màn hình khoá, trung tâm thông báo
6. [ ] Màn hình boot (Plymouth), đăng nhập (SDDM), trình cài đặt (Calamares)
