import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GPUStatusStore
    @Binding var appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Servers")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("编辑 SSH host alias、轮询周期和启用状态。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text("主题")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Button("Restore Defaults") {
                    store.restoreDefaults()
                }

                Button("Add Server") {
                    store.addServer()
                }
                .buttonStyle(.borderedProminent)
            }

            if store.configs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The repository ships with no built-in server config.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))

                    Text("Add your own SSH aliases here, or copy `config/server-config.template.json` as a private reference outside the repo.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
            }

            List {
                ForEach($store.configs) { $config in
                    HStack(spacing: 14) {
                        Toggle("", isOn: $config.isEnabled)
                            .toggleStyle(.switch)
                            .frame(width: 42)

                        TextField("Display name", text: $config.name)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 140)

                        TextField("SSH host alias", text: $config.hostAlias)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 160)

                        Stepper(value: $config.pollIntervalMinutes, in: 1...240) {
                            Text("\(config.pollIntervalMinutes) min")
                                .frame(width: 70, alignment: .leading)
                                .monospacedDigit()
                        }
                        .frame(width: 110)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { offsets in
                    store.deleteServers(at: offsets)
                }
            }

            Text("应用直接复用本机 `ssh` 配置和密钥，不保存密码。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
