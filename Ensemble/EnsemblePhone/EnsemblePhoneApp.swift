import SwiftUI

@main
struct EnsemblePhoneApp: App {
    @State private var appModel = PhoneAppModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if appModel.selectedPersona == nil {
                    PersonaPickerView(model: appModel)
                } else {
                    RoomControlView(model: appModel)
                }
            }
        }
    }
}
