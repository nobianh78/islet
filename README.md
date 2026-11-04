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
  assets/      icon
hypr/          cấu hình Hyprland mặc định (animation, blur, phím tắt)
scripts/       dev.sh (chạy thử), link.sh (gắn cấu hình vào ~/.config)
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

## Chạy thử

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
2. [ ] Thanh trên cùng, dock, trung tâm điều khiển, widget đồng hồ
3. [ ] Hoàn thiện cấu hình Hyprland, hình nền
4. [ ] Đóng ISO bằng `archiso`, chạy thử trong QEMU
5. [ ] Màn hình boot (Plymouth), đăng nhập (SDDM), trình cài đặt (Calamares)
