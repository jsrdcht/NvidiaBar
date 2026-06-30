import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GPUStatusStore
    @ObservedObject var themeController: ThemeController
    @ObservedObject var portForwardManager: PortForwardManager

    private var appTheme: AppTheme {
        themeController.appTheme
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if store.configs.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.configs) { config in
                            ServerEditorCard(
                                config: binding(for: config),
                                appTheme: appTheme,
                                portForwardManager: portForwardManager,
                                onDelete: {
                                    let id = config.id
                                    DispatchQueue.main.async {
                                        store.deleteServer(id: id)
                                    }
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
        .appTheme(appTheme)
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

                    Picker("Theme", selection: themeController.binding) {
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

    private func binding(for config: ServerConfig) -> Binding<ServerConfig> {
        Binding(
            get: {
                store.configs.first(where: { $0.id == config.id }) ?? config
            },
            set: { updatedConfig in
                guard let index = store.configs.firstIndex(where: { $0.id == updatedConfig.id }) else { return }
                store.configs[index] = updatedConfig
            }
        )
    }
}

private struct ServerEditorCard: View {
    @Binding var config: ServerConfig
    let appTheme: AppTheme
    @ObservedObject var portForwardManager: PortForwardManager
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

                Divider()
                    .overlay(appTheme.palette.cardStroke)

                PortForwardSection(
                    config: $config,
                    appTheme: appTheme,
                    portForwardManager: portForwardManager
                )
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

                LabeledTextField(title: "Identity File", text: $config.identityFile, prompt: "/path/to/private/key", appTheme: appTheme, monospace: true)
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

private struct PortForwardSection: View {
    @Binding var config: ServerConfig
    let appTheme: AppTheme
    @ObservedObject var portForwardManager: PortForwardManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("端口转发")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(appTheme.palette.primaryText)

                    Text("通过 SSH 把服务器端口转发到本机；点击“一键打开”会自动转发并在浏览器中访问。")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(appTheme.palette.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button("添加端口") {
                    config.portForwards.append(PortForward())
                }
                .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .secondary))
            }

            if config.portForwards.isEmpty {
                Text("还没有端口转发。点击“添加端口”，填好服务器端口（例如 8384）即可一键访问。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.tertiaryText)
            } else {
                VStack(spacing: 10) {
                    ForEach(config.portForwards) { forward in
                        PortForwardRow(
                            forward: binding(for: forward),
                            config: config,
                            appTheme: appTheme,
                            portForwardManager: portForwardManager,
                            onDelete: { deleteForward(id: forward.id) }
                        )
                    }
                }
            }
        }
    }

    private func deleteForward(id: UUID) {
        portForwardManager.stop(id)
        config.portForwards.removeAll { $0.id == id }
    }

    private func binding(for forward: PortForward) -> Binding<PortForward> {
        Binding(
            get: {
                config.portForwards.first(where: { $0.id == forward.id }) ?? forward
            },
            set: { updated in
                guard let index = config.portForwards.firstIndex(where: { $0.id == updated.id }) else { return }
                config.portForwards[index] = updated
            }
        )
    }
}

private struct PortForwardRow: View {
    @Binding var forward: PortForward
    let config: ServerConfig
    let appTheme: AppTheme
    @ObservedObject var portForwardManager: PortForwardManager
    let onDelete: () -> Void

    private var runtime: PortForwardManager.Runtime? {
        portForwardManager.runtime(for: forward.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LabeledTextField(title: "备注名（可选）", text: $forward.name, prompt: "例如：Jupyter", appTheme: appTheme)
                PortNumberField(title: "服务器端口", value: $forward.remotePort, appTheme: appTheme)
                    .frame(maxWidth: 120)
            }

            HStack(alignment: .bottom, spacing: 10) {
                LabeledTextField(title: "服务器内地址", text: $forward.remoteHost, prompt: "127.0.0.1", appTheme: appTheme, monospace: true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("本地端口")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(appTheme.palette.secondaryText)

                        Spacer()

                        Toggle("随机", isOn: randomBinding)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()

                        Text("随机")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(appTheme.palette.tertiaryText)
                    }

                    if forward.usesRandomLocalPort {
                        Text("启动时自动分配")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(appTheme.palette.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(appTheme.palette.secondaryControlFill)
                            )
                    } else {
                        PortNumberField(title: nil, value: $forward.localPort, appTheme: appTheme)
                    }
                }
                .frame(maxWidth: 150)
            }

            HStack(spacing: 10) {
                statusLabel

                Spacer()

                actionButtons

                Button("删除") {
                    onDelete()
                }
                .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .danger))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(appTheme.palette.cardFill.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(appTheme.palette.cardStroke, lineWidth: 1)
        )
    }

    private var randomBinding: Binding<Bool> {
        Binding(
            get: { forward.usesRandomLocalPort },
            set: { isRandom in
                if isRandom {
                    forward.localPort = 0
                } else if forward.localPort <= 0 {
                    forward.localPort = forward.normalizedRemotePort
                }
            }
        )
    }

    @ViewBuilder
    private var statusLabel: some View {
        if let phase = runtime?.phase {
            switch phase {
            case .starting:
                Text("连接中…")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(appTheme.palette.secondaryText)
            case .active:
                Text("● 127.0.0.1:\(runtime?.localPort ?? 0)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.25, green: 0.78, blue: 0.43))
            case let .failed(message):
                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.38))
                    .lineLimit(2)
            }
        } else {
            Text(forward.usesRandomLocalPort ? "随机本地端口" : "本地 \(forward.fixedLocalPort ?? forward.localPort)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(appTheme.palette.tertiaryText)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch runtime?.phase {
        case .active?:
            Button("打开") {
                portForwardManager.openBrowser(port: runtime?.localPort ?? 0)
            }
            .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .secondary))

            Button("停止") {
                portForwardManager.stop(forward.id)
            }
            .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .secondary))
        case .starting?:
            Button("停止") {
                portForwardManager.stop(forward.id)
            }
            .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .secondary))
        default:
            Button("一键打开") {
                portForwardManager.start(forward, config: config, openInBrowser: true)
            }
            .buttonStyle(SettingsActionButtonStyle(appTheme: appTheme, role: .primary))
        }
    }
}

private struct PortNumberField: View {
    let title: String?
    @Binding var value: Int
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(appTheme.palette.secondaryText)
            }

            TextField("端口", value: $value, format: .number.grouping(.never))
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
