import SwiftUI

/// @AppStorage keys shared by the toolbar, menu commands and the Settings window.
enum SettingsKey {
    static let syncScroll = "syncScroll"
    static let stackedLayout = "stackedLayout"
    static let fontSize = "editorFontSize"
}

enum SettingsDefault {
    static let syncScroll = false
    static let stackedLayout = false
    static let fontSize = 14.0
    static let fontSizeRange = 9.0...32.0
}

struct SettingsView: View {
    @AppStorage(SettingsKey.syncScroll) private var syncScroll = SettingsDefault.syncScroll
    @AppStorage(SettingsKey.stackedLayout) private var stackedLayout = SettingsDefault.stackedLayout
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsDefault.fontSize

    var body: some View {
        Form {
            Stepper(value: $fontSize, in: SettingsDefault.fontSizeRange, step: 1) {
                Text("Editor font size: \(Int(fontSize)) pt")
            }
            Toggle("Sync scroll (editor drives preview)", isOn: $syncScroll)
            Toggle("Stack editor above preview", isOn: $stackedLayout)
        }
        .padding(20)
        .frame(width: 380)
    }
}
