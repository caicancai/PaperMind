import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            AISettingsFormView(viewModel: viewModel)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 380)
    }
}
