import SwiftUI
import Shared

struct SettingsView: View {
    @EnvironmentObject var service: UsageService
    @State private var draftKey = ""
    @State private var saved = false
    @State private var launchAtLogin = LoginItemService.shared.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Session Key
            group {
                sectionHeader("Claude.ai Session Key")
                NativeTextField(text: $draftKey, placeholder: "sk-ant-sid...")
                    .padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to find it:").font(.caption.bold())
                    Text("1. Open claude.ai in your browser (logged in)")
                    Text("2. DevTools → Application → Cookies → claude.ai")
                    Text("3. Copy the value of the **sessionKey** cookie")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Divider().padding(.horizontal, 18)

            // General
            group {
                sectionHeader("General")
                if #available(macOS 13.0, *) {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { LoginItemService.shared.set($0) }
                } else {
                    HStack {
                        Text("Launch at login")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Requires macOS 13+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().padding(.horizontal, 18)

            // Refresh
            group {
                sectionHeader("Auto-refresh")
                Picker("", selection: Binding(
                    get: { service.refreshInterval },
                    set: { service.refreshInterval = $0 }
                )) {
                    Text("1 min").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                    Text("15 min").tag(900.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider().padding(.horizontal, 18)

            // Save row
            HStack {
                if saved {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
                Spacer()
                Button("Save & Refresh") {
                    service.sessionKey = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { saved = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .frame(width: 420)
        .onAppear { draftKey = service.sessionKey }
    }

    @ViewBuilder
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}
