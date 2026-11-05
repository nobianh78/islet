-- Islet – cấu hình Hyprland mặc định (Hyprland 0.57+, cấu hình Lua)
-- Màu lấy từ logo: tím #8B7CFF, hồng #FF6B97, mực #07070F

-- Ưu tiên bản shell đang phát triển ở ~/.config/islet/shell (scripts/link.sh), sau đó tới bản hệ thống.
local function exists(p)
    local ok, f = pcall(function() return io and io.open(p, "r") end)
    if ok and f then f:close(); return true end
    return false
end
local devShell = (os.getenv("HOME") or "") .. "/.config/islet/shell"
local shellDir = os.getenv("ISLET_SHELL")
    or (exists(devShell .. "/shell.qml") and devShell)
    or "/usr/share/islet/shell"
local qs       = "qs -p " .. shellDir

local terminal    = "kitty"
local browser     = "firefox"
local fileManager = "nautilus"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

------------------------------------------------------------
-- Khởi động: shell Islet (island + hình nền)
------------------------------------------------------------
hl.on("hyprland.start", function()
    -- Đưa biến Wayland cho systemd / D-Bus, để app mở qua D-Bus (Files, portal…) cũng biết là Wayland
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP ELECTRON_OZONE_PLATFORM_HINT HYPRLAND_INSTANCE_SIGNATURE")
    -- ISLET_BOOT=1: shell biết là vừa bật máy → vào thẳng màn hình khoá, nối tiếp màn hình khởi động
    hl.exec_cmd("env ISLET_BOOT=1 " .. qs)
    -- App GTK: nút cửa sổ bên trái theo thứ tự đóng · thu nhỏ · phóng to (CSS tô thành 🔴🟡🟢)
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'")
    -- theme nút cửa sổ 🔴🟡🟢 cho mọi profile Firefox
    hl.exec_cmd("islet-firefox-theme")
    -- bộ icon Islet (thư mục, thùng rác, app) cho GTK / Nautilus
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Islet'")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- Báo cho app biết đây là phiên Wayland. Thiếu cái này, app Electron (VS Code, Cursor, Antigravity,
-- Discord…) thử X11 trước rồi mới chịu chạy → mở mất 20–30 giây thay vì 1 giây.
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("GDK_BACKEND", "wayland,x11")

------------------------------------------------------------
-- Giao diện
------------------------------------------------------------
hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 14,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(8b7cffee)", "rgba(ff6b97ee)" }, angle = 45 },
            inactive_border = "rgba(ffffff14)",
        },
        resize_on_border = true,
        extend_border_grab_area = 12,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 18,
        rounding_power = 2.6,          -- góc "squircle" mềm như iOS
        active_opacity   = 1.0,     -- độ trong của kính do từng app lo (vd. kitty)
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 3,
            color        = 0x66000000,
        },

        blur = {
            enabled  = true,
            size     = 8,
            passes   = 3,
            noise    = 0.02,
            vibrancy = 0.25,
            popups   = true,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        background_color = 0xff0a0a14,
    },

    -- Máy ảo (QEMU/virgl) thường vẽ con trỏ phần cứng bị lỗi.
    cursor = { no_hardware_cursors = true },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        touchpad     = { natural_scroll = true },
    },
})

------------------------------------------------------------
-- Chuyển động
--   cửa sổ mở: lò xo nảy + phóng to từ 82%
--   cửa sổ đóng: thu nhỏ mượt
--   workspace: trượt + mờ
------------------------------------------------------------
hl.curve("smooth", { type = "bezier", points = { {0.22, 1},   {0.36, 1} } })
hl.curve("snappy", { type = "bezier", points = { {0.2, 0.9},  {0.1, 1.05} } })
hl.curve("linear", { type = "bezier", points = { {0, 0},      {1, 1} } })
hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 220, damping = 16 })
hl.curve("soft",   { type = "spring", mass = 1, stiffness = 180, damping = 22 })

hl.animation({ leaf = "global",      enabled = true, speed = 8,   bezier = "default" })
hl.animation({ leaf = "windows",     enabled = true, speed = 5,   spring = "soft" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4.5, spring = "bouncy", style = "popin 82%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.2, bezier = "smooth", style = "popin 88%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, spring = "soft" })
hl.animation({ leaf = "fade",        enabled = true, speed = 3,   bezier = "smooth" })
hl.animation({ leaf = "border",      enabled = true, speed = 6,   bezier = "smooth" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 80,  bezier = "linear", style = "loop" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 3.5, spring = "bouncy", style = "popin 92%" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 2,   bezier = "smooth", style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,   bezier = "smooth", style = "slidefade 18%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, spring = "bouncy", style = "slidevert" })

-- Island và hình nền tự lo chuyển động của mình.
hl.layer_rule({ name = "islet-island-noanim", match = { namespace = "^islet-island$" }, no_anim = true })
hl.layer_rule({ name = "islet-wall-noanim",   match = { namespace = "^islet-wallpaper$" }, no_anim = true })
hl.layer_rule({ name = "islet-bar-noanim",    match = { namespace = "^islet-bar$" },       no_anim = true })
hl.layer_rule({ name = "islet-cc-noanim",     match = { namespace = "^islet-cc$" },        no_anim = true })
hl.layer_rule({ name = "islet-frame-noanim",  match = { namespace = "^islet-frame$" },     no_anim = true })
hl.layer_rule({ name = "islet-dockmenu-noanim", match = { namespace = "^islet-dockmenu$" }, no_anim = true })
hl.layer_rule({ name = "islet-store-noanim", match = { namespace = "^islet-store$" }, no_anim = true })
hl.layer_rule({ name = "islet-installer-noanim", match = { namespace = "^islet-installer$" }, no_anim = true })
hl.layer_rule({ name = "islet-taskmgr-noanim", match = { namespace = "^islet-taskmgr$" }, no_anim = true })
hl.layer_rule({ name = "islet-settings-noanim", match = { namespace = "^islet-settings$" }, no_anim = true })
hl.layer_rule({ name = "islet-notifs-noanim", match = { namespace = "^islet-notifs$" }, no_anim = true })
hl.layer_rule({ name = "islet-power-noanim",  match = { namespace = "^islet-power$" },     no_anim = true })
hl.layer_rule({ name = "islet-launcher-noanim", match = { namespace = "^islet-launcher$" }, no_anim = true })
hl.layer_rule({ name = "islet-tabs-noanim",   match = { namespace = "^islet-tabs$" },      no_anim = true })

-- Kính mờ thật: nhoè phần phía sau dock, trung tâm điều khiển và widget đồng hồ.
hl.layer_rule({
    name  = "islet-glass",
    match = { namespace = "^islet-(dock|dockmenu|cc|tabs|launcher|power|taskmgr|installer|store|settings|notifs)$" },
    blur  = true,
    ignore_alpha = 0.05,
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

------------------------------------------------------------
-- Phím tắt
------------------------------------------------------------
local mod = "SUPER"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + C",      hl.dsp.exec_cmd("code-oss"))           -- trình soạn code
hl.bind(mod .. " + Q",      hl.dsp.window.close())
hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F",      hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + N",      hl.dsp.exec_cmd(qs .. " ipc call win minimize"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))

-- Island
hl.bind(mod .. " + I", hl.dsp.exec_cmd(qs .. " ipc call island toggle"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd(qs .. " ipc call cc toggle"))
hl.bind(mod .. " + space", hl.dsp.exec_cmd(qs .. " ipc call launcher toggle"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(qs .. " ipc call taskmgr toggle"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd(qs .. " ipc call lock lock"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(qs .. " ipc call notifs toggle"))
hl.bind(mod .. " + comma",     hl.dsp.exec_cmd(qs .. " ipc call settings toggle"))

-- Chụp màn hình (Print: cả màn hình, Shift+Print: chọn vùng); island báo khi xong.
local shot = 'f=~/Pictures/islet-$(date +%Y%m%d-%H%M%S).png; mkdir -p ~/Pictures; '
hl.bind("Print",         hl.dsp.exec_cmd("sh -c '" .. shot .. "grim \"$f\" && notify-send -a \"Screenshot\" \"Saved\" \"$f\"'"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("sh -c '" .. shot .. "grim -g \"$(slurp)\" \"$f\" && notify-send -a \"Screenshot\" \"Saved\" \"$f\"'"))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Âm lượng / media (island tự hiện thanh âm lượng)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Máy ảo thường không có phím media: dùng Super + phím cộng/trừ để thử island.
hl.bind(mod .. " + equal", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind(mod .. " + minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { repeating = true })

-- (Không chặn yêu cầu phóng to của app: nút ▢ trên thanh tiêu đề của app cần nó.)

-- Cửa sổ đang phóng to / toàn màn hình: bỏ viền màu, bo góc và bóng, nằm phẳng sát mép.
hl.window_rule({ name = "islet-maximized-flat", match = { fullscreen = true }, border_size = 0, rounding = 0 })

-- Cửa sổ mở tự do (nổi), không tự chia màn hình. Mỗi app tự chọn kích thước, Islet đặt vào giữa.
-- Muốn xếp ô lại cho một cửa sổ: Super+V.  Kéo: giữ Super + kéo chuột trái, hoặc kéo thanh tiêu đề của app.
-- App tự xin thu nhỏ (Firefox, …): Hyprland không có "thu nhỏ" → cất vào workspace ẩn.
-- Bấm icon app trên dock để lấy lại.
hl.on("window.minimize", function(w)
    if w and w.address then
        hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:" .. w.address }))
    end
end)

hl.window_rule({ name = "islet-float-all", match = { class = ".*" }, float = true, center = true })

-- Cài đặt riêng của người dùng (màu nhấn, màn hình) do app Cài đặt của Islet ghi ra
local userConf = (os.getenv("HOME") or "") .. "/.config/islet/hypr-user.lua"
if exists(userConf) then pcall(dofile, userConf) end
