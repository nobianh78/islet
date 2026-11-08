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
    -- bộ gõ tiếng Việt (tắt được trong Cài đặt › Keyboard & Language)
    hl.exec_cmd("sh -c 'grep -q \"imeEnabled\": false ~/.config/islet/settings.json 2>/dev/null || exec fcitx5 -d'")
    -- app tự mở khi đăng nhập (Cài đặt › Startup Apps)
    hl.exec_cmd("islet-autostart")
    -- kết nối điện thoại (Cài đặt › Phone): thông báo từ điện thoại lên Dynamic Island, clipboard chung
    hl.exec_cmd("sh -c 'command -v kdeconnectd >/dev/null && exec kdeconnectd'")
    -- App GTK: nút cửa sổ bên trái theo thứ tự đóng · thu nhỏ · phóng to (CSS tô thành 🔴🟡🟢)
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'")
    -- theme nút cửa sổ 🔴🟡🟢 cho mọi profile Firefox
    hl.exec_cmd("islet-firefox-theme")
    -- bộ icon Islet (thư mục, thùng rác, app) cho GTK / Nautilus
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Islet'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Islet-Cursors'")
end)

-- con trỏ chuột của Islet (theme/cursors, vẽ bằng scripts/make-cursors.py)
hl.env("XCURSOR_THEME", "Islet-Cursors")
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
-- Bộ gõ tiếng Việt (fcitx5 + Bamboo): app Qt / SDL / X11 cần biết; GTK & Electron dùng text-input của Wayland
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")

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
hl.layer_rule({ name = "islet-dim-noanim", match = { namespace = "^islet-dim$" }, no_anim = true })
hl.layer_rule({ name = "islet-overview-noanim", match = { namespace = "^islet-overview$" }, no_anim = true })
hl.layer_rule({ name = "islet-search-noanim", match = { namespace = "^islet-search$" }, no_anim = true })
hl.layer_rule({ name = "islet-snap-noanim", match = { namespace = "^islet-snap" }, no_anim = true })
hl.layer_rule({ name = "islet-notifs-noanim", match = { namespace = "^islet-notifs$" }, no_anim = true })
hl.layer_rule({ name = "islet-power-noanim",  match = { namespace = "^islet-power$" },     no_anim = true })
hl.layer_rule({ name = "islet-launcher-noanim", match = { namespace = "^islet-launcher$" }, no_anim = true })
hl.layer_rule({ name = "islet-tabs-noanim",   match = { namespace = "^islet-tabs$" },      no_anim = true })
hl.layer_rule({ name = "islet-desktop-noanim", match = { namespace = "^islet-desktop$" }, no_anim = true })
hl.layer_rule({ name = "islet-welcome-noanim", match = { namespace = "^islet-welcome$" }, no_anim = true })
hl.layer_rule({ name = "islet-widgets-noanim", match = { namespace = "^islet-widgets$" }, no_anim = true })
hl.layer_rule({ name = "islet-ql-noanim", match = { namespace = "^islet-quicklook$" }, no_anim = true })

-- Kính mờ thật: nhoè phần phía sau dock, trung tâm điều khiển và widget đồng hồ.
hl.layer_rule({
    name  = "islet-glass",
    match = { namespace = "^islet-(dock|dockmenu|cc|tabs|launcher|power|taskmgr|installer|store|settings|notifs|snappicker|search|desktop|welcome|bar)$" },
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
hl.bind(mod .. " + space", hl.dsp.exec_cmd(qs .. " ipc call search toggle"))
hl.bind(mod .. " + SHIFT + space", hl.dsp.exec_cmd(qs .. " ipc call launcher toggle"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(qs .. " ipc call taskmgr toggle"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd(qs .. " ipc call lock lock"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(qs .. " ipc call notifs toggle"))
hl.bind(mod .. " + comma",     hl.dsp.exec_cmd(qs .. " ipc call settings toggle"))

-- Chụp màn hình: Print = cả màn hình (chép + lưu) · Shift+Print / Super+Shift+S = chọn vùng rồi vẽ (Satty)
hl.bind("Print",              hl.dsp.exec_cmd("islet-shot full"))
hl.bind("SHIFT + Print",      hl.dsp.exec_cmd("islet-shot area"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("islet-shot area"))
-- Quay màn hình: Super+Shift+R (chọn vùng, Esc = cả màn hình); bấm island để dừng
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(qs .. " ipc call recorder toggle"))

hl.bind(mod .. " + ALT + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + ALT + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + ALT + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + ALT + down", hl.dsp.focus({ direction = "down" }))

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

-- ============================================================================
-- Xếp cửa sổ kiểu Windows 11 + giữ cửa sổ trong vùng làm việc
--   · cửa sổ mới to quá vùng trống (trừ thanh trên + dock) → thu lại cho vừa, đặt giữa
--   · kéo cửa sổ ra mép trái/phải = nửa màn hình, 4 góc = 1/4, mép trên = phóng to;
--     trong lúc kéo shell vẽ khung xem trước (islet-ipc snap preview/clear), CHỈ xếp khi thả chuột
--     (bắt sự kiện thả chuột trái bằng bind release + non_consuming; Hyprland không có sự kiện "thả")
--   · Super+←/→/↑ xếp nhanh, Super+↓ trả về cỡ cũ, Super+Z mở lưới bố cục
--   · kéo cửa sổ đang xếp ra chỗ khác → về lại cỡ trước khi xếp
-- ============================================================================
local SNAP_GAP = 10
local snapPrev = {}          -- address → {x, y, w, h} trước khi xếp
local snapped = {}           -- address → tên vùng

local function workarea(m)
    local s = m.scale or 1
    local r = m.reserved or {}
    local top, bottom, left, right = r.top or 0, r.bottom or 0, r.left or 0, r.right or 0
    local W, H = m.width / s, m.height / s
    return { x = m.x + left + SNAP_GAP, y = m.y + top + SNAP_GAP,
             w = W - left - right - 2 * SNAP_GAP, h = H - top - bottom - 2 * SNAP_GAP }
end

local function zoneRect(z, a)
    local G = SNAP_GAP
    local hw, hh = (a.w - G) / 2, (a.h - G) / 2
    local tw = (a.w - 2 * G) / 3
    local R = {
        max = { a.x, a.y, a.w, a.h },
        left = { a.x, a.y, hw, a.h },             right = { a.x + hw + G, a.y, hw, a.h },
        tl = { a.x, a.y, hw, hh },                tr = { a.x + hw + G, a.y, hw, hh },
        bl = { a.x, a.y + hh + G, hw, hh },       br = { a.x + hw + G, a.y + hh + G, hw, hh },
        l3 = { a.x, a.y, tw, a.h },               c3 = { a.x + tw + G, a.y, tw, a.h },
        r3 = { a.x + 2 * (tw + G), a.y, tw, a.h },
        l23 = { a.x, a.y, 2 * tw + G, a.h },      r23 = { a.x + tw + G, a.y, 2 * tw + G, a.h },
        top = { a.x, a.y, a.w, hh },              bottom = { a.x, a.y + hh + G, a.w, hh },
    }
    return R[z]
end

local drag = { addr = nil, x = 0, y = 0, sw = 0, sh = 0, moving = false, still = 0, zone = nil, shown = nil, ignore = 0 }

local function setGeom(addr, g)
    drag.ignore = 8          -- bỏ qua vài nhịp: đây là mình dời, không phải người dùng kéo
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(g[3]), y = math.floor(g[4]), window = "address:" .. addr }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(g[1]), y = math.floor(g[2]), window = "address:" .. addr }))
end

local function findWindow(addr)
    if not addr or addr == "" then return hl.get_active_window() end
    for _, w in ipairs(hl.get_windows() or {}) do
        if w.address == addr then return w end
    end
    return nil
end

-- islet_snap("left" | "tl" | ... | "max" | "restore", address?) — dùng cả từ shell (hyprctl eval)
function islet_snap(z, addr)
    local w = findWindow(addr)
    if not w or not w.monitor then return end
    if (w.fullscreen or 0) ~= 0 then hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" })) end
    if z == "restore" then
        local p = snapPrev[w.address]
        if p then setGeom(w.address, p) end
        snapPrev[w.address], snapped[w.address] = nil, nil
        return
    end
    local g = zoneRect(z, workarea(w.monitor))
    if not g then return end
    if not snapped[w.address] then snapPrev[w.address] = { w.at.x, w.at.y, w.size.x, w.size.y } end
    snapped[w.address] = z
    setGeom(w.address, g)
end

local function zoneAt(m, c)
    local s = m.scale or 1
    local W, H = m.width / s, m.height / s
    local cx, cy = c.x - m.x, c.y - m.y
    local e, corner = 6, H * 0.2
    if cx <= e then return (cy < corner and "tl") or (cy > H - corner and "bl") or "left" end
    if cx >= W - e then return (cy < corner and "tr") or (cy > H - corner and "br") or "right" end
    if cy <= e then return "max" end
    return nil
end

local function preview(z, m)
    if z == drag.shown then return end
    drag.shown = z
    if not z or not m then
        hl.exec_cmd("islet-ipc snap clear")
        return
    end
    local g = zoneRect(z, workarea(m))
    hl.exec_cmd(string.format("islet-ipc snap preview %d %d %d %d", math.floor(g[1]), math.floor(g[2]), math.floor(g[3]), math.floor(g[4])))
end

hl.timer(function()
    local w = hl.get_active_window()
    if not w or not w.floating or (w.fullscreen or 0) ~= 0 then
        if drag.shown then preview(nil) end
        drag.addr, drag.moving = nil, false
        return
    end
    local x, y, sw, sh = w.at.x, w.at.y, w.size.x, w.size.y
    if w.address ~= drag.addr then
        drag.addr, drag.x, drag.y, drag.sw, drag.sh, drag.moving, drag.still = w.address, x, y, sw, sh, false, 0
        return
    end
    if drag.ignore > 0 then
        drag.ignore = drag.ignore - 1
        drag.x, drag.y, drag.sw, drag.sh = x, y, sw, sh
        return
    end
    local moved = (x ~= drag.x or y ~= drag.y) and sw == drag.sw and sh == drag.sh
    drag.x, drag.y, drag.sw, drag.sh = x, y, sw, sh
    if moved then
        if not drag.moving then
            drag.moving = true
            -- kéo cửa sổ đang xếp ra → về lại cỡ trước khi xếp (giữ con trỏ ở giữa thanh tiêu đề)
            local p = snapPrev[w.address]
            if snapped[w.address] and p then
                local c = hl.get_cursor_pos()
                snapped[w.address], snapPrev[w.address] = nil, nil
                setGeom(w.address, { c.x - p[3] / 2, c.y - 20, p[3], p[4] })
                drag.moving = true
            end
        end
        drag.still = 0
        local m = hl.get_monitor_at_cursor() or w.monitor
        drag.zone = zoneAt(m, hl.get_cursor_pos())
        preview(drag.zone, m)
    end
end, { timeout = 40, type = "repeat" })

-- thả chuột trái (kéo thanh tiêu đề hoặc Super+kéo) → nếu đang ở vùng xếp thì xếp
local function onRelease()
    if drag.moving and drag.zone and drag.addr then
        local z, addr = drag.zone, drag.addr
        preview(nil)
        islet_snap(z, addr)
    else
        preview(nil)
    end
    drag.moving, drag.zone = false, nil
end
hl.bind("mouse:272", onRelease, { release = true, non_consuming = true })
hl.bind(mod .. " + mouse:272", onRelease, { release = true, non_consuming = true })

-- cửa sổ mới to quá vùng làm việc → thu lại, đặt giữa (không chui dưới thanh trên / dock)
hl.on("window.open", function(w)
    if not w or not w.address then return end
    local addr = w.address
    hl.timer(function()
        local win = findWindow(addr)
        if not win or not win.floating or not win.monitor or (win.fullscreen or 0) ~= 0 then return end
        local a = workarea(win.monitor)
        local ww, wh = win.size.x, win.size.y
        if ww <= a.w and wh <= a.h and win.at.y >= a.y - SNAP_GAP then return end
        local nw, nh = math.min(ww, a.w), math.min(wh, a.h)
        setGeom(addr, { a.x + (a.w - nw) / 2, a.y + (a.h - nh) / 2, nw, nh })
    end, { timeout = 120, type = "oneshot" })
end)

hl.bind(mod .. " + left",  function() islet_snap("left") end)
hl.bind(mod .. " + right", function() islet_snap("right") end)
hl.bind(mod .. " + up",    function() islet_snap("max") end)
hl.bind(mod .. " + down",  function() islet_snap("restore") end)
hl.bind(mod .. " + Z",     hl.dsp.exec_cmd(qs .. " ipc call snap picker"))

-- ============================================================================
-- Touchpad: vuốt 3 ngón ngang = đổi workspace · 3 ngón lên / chụm 4 ngón = Overview · 3 ngón xuống = đóng
-- (cuộn tự nhiên, chạm để bấm, tốc độ… nằm trong hypr-user.lua do Cài đặt › Mouse & Touchpad ghi ra)
-- ============================================================================
hl.gesture({ fingers = 3, direction = "up",   action = function() hl.exec_cmd(qs .. " ipc call overview open") end })
hl.gesture({ fingers = 3, direction = "down", action = function() hl.exec_cmd(qs .. " ipc call overview close") end })
hl.gesture({ fingers = 4, direction = "pinch", action = function() hl.exec_cmd(qs .. " ipc call overview toggle") end })
hl.bind(mod .. " + TAB", hl.dsp.exec_cmd(qs .. " ipc call overview toggle"))

-- Gập / mở laptop: shell khoá màn hình rồi mới ngủ (systemd-logind để Islet lo: islet-lid.conf)
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(qs .. " ipc call power lid true"),  { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(qs .. " ipc call power lid false"), { locked = true })

-- Cài đặt riêng của người dùng (màu nhấn, màn hình) do app Cài đặt của Islet ghi ra
local userConf = (os.getenv("HOME") or "") .. "/.config/islet/hypr-user.lua"
if exists(userConf) then pcall(dofile, userConf) end
