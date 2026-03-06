import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GPUStatusStore
    @Binding var appTheme: AppTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if store.configs.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach($store.configs) { $config in
                            ServerEditorCard(
                                config: $config,
                                appTheme: appTheme,
                                onDelete: {
                                    store.deleteServer(id: config.id)
                                }
                            )
                        }
                    }
                }

                footerNote
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: appTheme.palette.windowGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("服务器设置")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(appTheme.palette.primaryText)

                    Text("启动时会自动读取 `~/.ssh/config`。你也可以手动添加完整的主机、用户名、端口、密钥和密码。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(appTheme.palette.secondaryText)
                }

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("主题")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appTheme.palette.tertiaryText)

                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }

            HStack(spacing: 10) {
                Button("重新导入 SSH 配置") {
                    store.importAvailableServers()
                }
                .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .secondary))

                Button("恢复默认") {
                    store.restoreDefaults()
                }
                .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .secondary))

                Button("添加服务器") {
                    store.addServer()
                }
                .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .primary))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(appTheme.palette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(appTheme.palette.panelStroke, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有服务器")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(appTheme.palette.primaryText)

            Text("先点击“重新导入 SSH 配置”，或者手动添加一台服务器。公开仓库只保留模板值，不会附带你的真实服务器信息。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(appTheme.palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(appTheme.palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(appTheme.palette.cardStroke, lineWidth: 1)
        )
    }

    private var footerNote: some View {
        Text("密码只保存在当前 Mac 的本地设置中，不会写入仓库。若你已有 SSH alias，优先使用“SSH 别名”模式；若要脱离本机 ssh 配置，改用“直接连接”模式。")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(appTheme.palette.secondaryText)
            .padding(.horizontal, 4)
    }
}

private struct ServerEditorCard: View {
    @Binding var config: ServerConfig
    let appTheme: AppTheme
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(appTheme.palette.primaryText)

                    Text(config.connectionSummary)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(appTheme.palette.tertiaryText)
                }

                Spacer()

                Toggle("启用", isOn: $config.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()

                Button("删除") {
                    onDelete()
                }
                .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .danger))
            }

            VStack(alignment: .leading, spacing: 10) {
                LabeledTextField(title: "显示名称", text: $config.name, prompt: "例如：实验室 1", appTheme: appTheme)

                VStack(alignment: .leading, spacing: 6) {
                    Text("连接方式")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appTheme.palette.secondaryText)

                    Picker("Connection Mode", selection: $config.connectionMode) {
                        ForEach(ServerConnectionMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if config.connectionMode == .sshAlias {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledTextField(title: "SSH 别名", text: $config.hostAlias, prompt: "例如：gpu-server-1", appTheme: appTheme, monospace: true)
                        ImportedMetadataRow(config: config, appTheme: appTheme)
                    }
                } else {
                    directConnectionFields
                }

                HStack(spacing: 12) {
                    Stepper(value: $config.pollIntervalMinutes, in: 1...240) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("轮询周期")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(appTheme.palette.secondaryText)

                            Text("\(config.pollIntervalMinutes) 分钟")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(appTheme.palette.primaryText)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(appTheme.palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(appTheme.palette.cardStroke, lineWidth: 1)
        )
    }

    private var directConnectionFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                LabeledTextField(title: "主机/IP", text: $config.hostName, prompt: "例如：192.168.1.20", appTheme: appTheme, monospace: true)
                LabeledTextField(title: "用户名", text: $config.userName, prompt: "例如：gpu-user", appTheme: appTheme, monospace: true)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("端口")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(appTheme.palette.secondaryText)

                    Stepper(value: $config.port, in: 1...65_535) {
                        Text("\(config.normalizedPort)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(appTheme.palette.primaryText)
                    }
                }
                .frame(maxWidth: 120, alignment: .leading)

                LabeledTextField(title: "Identity File", text: $config.identityFile, prompt: "~/.ssh/id_rsa", appTheme: appTheme, monospace: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("密码")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(appTheme.palette.secondaryText)

                SecureField("可选，留空则只使用 SSH 密钥", text: $config.password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(appTheme.palette.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(appTheme.palette.secondaryControlFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(appTheme.palette.secondaryControlStroke, lineWidth: 1)
                    )
            }
        }
    }
}

private struct ImportedMetadataRow: View {
    let config: ServerConfig
    let appTheme: AppTheme

    var body: some View {
        let details = [
            config.trimmedHostName.isEmpty ? nil : "Host \(config.trimmedHostName)",
            config.trimmedUserName.isEmpty ? nil : "User \(config.trimmedUserName)",
            "Port \(config.normalizedPort)",
            config.trimmedIdentityFile.isEmpty ? nil : "Key \(config.trimmedIdentityFile)"
        ].compactMap { $0 }

        if details.isEmpty {
            Text("当前只记录了别名，具体主机信息会由本机 ssh 配置解析。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(appTheme.palette.tertiaryText)
        } else {
            Text(details.joined(separator: "  ·  "))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(appTheme.palette.tertiaryText)
        }
    }
}

private struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let appTheme: AppTheme
    var monospace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(appTheme.palette.secondaryText)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: monospace ? .monospaced : .rounded))
                .foregroundStyle(appTheme.palette.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(appTheme.palette.secondaryControlFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(appTheme.palette.secondaryControlStroke, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsActionButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case danger
    }

    let appTheme: AppTheme
    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor.opacity(configuration.isPressed ? 0.86 : 1))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.92 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return Color(red: 0.04, green: 0.10, blue: 0.06)
        case .secondary:
            return appTheme.palette.primaryText
        case .danger:
            return Color(red: 0.95, green: 0.38, blue: 0.34)
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .primary:
            return Color(red: 0.24, green: 0.78, blue: 0.42)
        case .secondary:
            return appTheme.palette.secondaryControlFill
        case .danger:
            return Color(red: 0.95, green: 0.38, blue: 0.34).opacity(appTheme == .dark ? 0.16 : 0.12)
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return Color.clear
        case .secondary:
            return appTheme.palette.secondaryControlStroke
        case .danger:
            return Color(red: 0.95, green: 0.38, blue: 0.34).opacity(0.28)
        }
    }
}
