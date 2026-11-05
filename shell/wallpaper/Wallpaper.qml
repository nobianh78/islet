import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../services"

// Hình nền: ba đốm màu nhoè trôi chậm trên nền tối (bộ màu chọn trong Cài đặt → Hình nền),
// hoặc một ảnh bất kỳ. Đổi hình nền thì màu chuyển mượt / ảnh mờ dần sang ảnh mới.
// Vẽ ở 1/4 độ phân giải rồi phóng to, nên rất nhẹ mà vẫn mềm.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Prefs.preset.base
    focusable: false

    WlrLayershell.namespace: "islet-wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    Backdrop { anchors.fill: parent }

    // hình nền chỉ trôi khi màn hình nền trống (không cửa sổ, không panel) hoặc đang khoá
    Binding {
        target: Drift
        property: "active"
        value: Ui.locked || (ToplevelManager.toplevels.values.filter(t => !t.minimized).length === 0
            && !Ui.settingsOpen && !Ui.storeOpen && !Ui.launcherOpen && !Ui.controlCenterOpen && !Ui.notifOpen && !Ui.taskOpen && !Ui.installerOpen)
    }
}
