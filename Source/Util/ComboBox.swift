import Foundation
import SwiftUI

struct ComboBox: NSViewRepresentable
{
    let placeholder: String
    let text: Binding<String>
    let items: [String]
    
    init(_ placeholder: String, text: Binding<String>, items: [String]) {
        self.placeholder = placeholder
        self.text = text
        self.items = items
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: text)
    }
    
    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.completes = true
        comboBox.delegate = context.coordinator
//        comboBox.font = context.environment.font
//        comboBox.isButtonBordered = true
//        comboBox.intercellSpacing = NSSize(width: 0.0, height: 10.0)            // Matches the look and feel of Big Sur onwards.
        return comboBox
    }
    
    func updateNSView(_ nsView: NSComboBox, context: Context) {
        nsView.placeholderString = placeholder

        nsView.removeAllItems()
        nsView.addItems(withObjectValues: items)

        // ComboBox doesn't automatically select the item matching its text; we must do that manually.
        context.coordinator.ignoreSelectionChanges = true
        nsView.stringValue = text.wrappedValue
        nsView.selectItem(withObjectValue: text)
        context.coordinator.ignoreSelectionChanges = false
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSComboBoxDelegate {
        var text: Binding<String>
        var ignoreSelectionChanges: Bool = false

        init(text: Binding<String>) {
            self.text = text
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            if !ignoreSelectionChanges,
               let box: NSComboBox = notification.object as? NSComboBox,
               let newStringValue: String = box.objectValueOfSelectedItem as? String
            {
                text.wrappedValue = newStringValue
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text.wrappedValue = textField.stringValue
            }
        }
    }
}
