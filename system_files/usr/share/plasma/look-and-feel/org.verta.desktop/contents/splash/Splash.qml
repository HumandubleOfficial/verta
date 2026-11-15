// Verta login splash: the V scales in, the orbit ring spins around it, the
// wordmark fades up, and a thin progress line fills as Plasma starts.
import QtQuick

Rectangle {
    id: root
    color: "#040814"

    // Set by ksplash: 1..6 as the session starts up.
    property int stage

    Item {
        id: mark
        width: 168
        height: 168
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -36

        Image {
            id: ring
            anchors.fill: parent
            source: "images/logo-ring.svg"
            sourceSize.width: 336
            sourceSize.height: 336
            smooth: true
            opacity: 0

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 1600
                loops: Animation.Infinite
                running: true
            }
        }

        Image {
            id: vee
            anchors.fill: parent
            source: "images/logo-v.svg"
            sourceSize.width: 336
            sourceSize.height: 336
            smooth: true
            opacity: 0
            scale: 0.6
        }
    }

    Text {
        id: wordmark
        anchors.top: mark.bottom
        anchors.topMargin: 36
        anchors.horizontalCenter: parent.horizontalCenter
        text: "VERTA"
        color: "#e6ebf5"
        font.family: "Inter"
        font.pixelSize: 22
        font.weight: Font.DemiBold
        font.letterSpacing: 10
        opacity: 0
    }

    Rectangle {
        id: track
        anchors.top: wordmark.bottom
        anchors.topMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter
        width: 180
        height: 3
        radius: 1.5
        color: "#16213a"
        opacity: 0

        Rectangle {
            height: parent.height
            radius: parent.radius
            color: "#3b82f6"
            width: parent.width * Math.min(root.stage, 6) / 6
            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
    }

    // Entrance: V pops in, ring fades in, then the wordmark and progress line.
    SequentialAnimation {
        running: true
        ParallelAnimation {
            NumberAnimation { target: vee; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: vee; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutBack }
            NumberAnimation { target: ring; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: wordmark; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { target: wordmark; property: "anchors.topMargin"; from: 48; to: 36; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { target: track; property: "opacity"; to: 1; duration: 350 }
        }
    }

    // Exit: fade everything out as the desktop appears.
    onStageChanged: if (stage >= 6) exitAnimation.start()
    NumberAnimation {
        id: exitAnimation
        target: root
        property: "opacity"
        to: 0
        duration: 300
        easing.type: Easing.InCubic
    }
}
