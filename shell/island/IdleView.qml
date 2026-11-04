import QtQuick

// Island lúc rảnh: chỉ có đôi mắt mèo.
View {
    id: root
    width: 132
    height: 36

    property bool hovered: false

    CatEyes {
        anchors.centerIn: parent
        happy: root.hovered
    }
}
