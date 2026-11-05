# Islet Live: tự vào Hyprland khi đăng nhập ở tty1.
[[ -f ~/.bashrc ]] && . ~/.bashrc
if [[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]]; then
    if command -v start-hyprland >/dev/null; then
        exec start-hyprland > ~/.hyprland.log 2>&1
    else
        exec Hyprland > ~/.hyprland.log 2>&1
    fi
fi
