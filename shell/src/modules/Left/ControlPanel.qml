import QtQuick
import "../../components"
import "../../"

IconBtn {
		text: "" 
		textColor: "#FF6699"
		onClicked: {
        var next = !Popups.archMenuOpen
        Popups.closeAll()
        Popups.archMenuOpen = next
    }
}
