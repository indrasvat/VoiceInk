import SwiftUI
import SwiftData

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

enum ConfigurationMode: Hashable {
    case add
    case edit(PowerModeConfig)
    
    var isAdding: Bool {
        if case .add = self { return true }
        return false
    }
    
    var title: String {
        switch self {
        case .add: return "Add Power Mode"
        case .edit: return "Edit Power Mode"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let config):
            hasher.combine(1)
            hasher.combine(config.id)
        }
    }
    
    static func == (lhs: ConfigurationMode, rhs: ConfigurationMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add):
            return true
        case (.edit(let lhsConfig), .edit(let rhsConfig)):
            return lhsConfig.id == rhsConfig.id
        default:
            return false
        }
    }
}

enum ConfigurationType {
    case application
    case website
}

let commonEmojis = ["🏢", "🏠", "💼", "🎮", "📱", "📺", "🎵", "📚", "✏️", "🎨", "🧠", "⚙️", "💻", "🌐", "📝", "📊", "🔍", "💬", "📈", "🔧"]

struct PowerModeView: View {
    @StateObject private var powerModeManager = PowerModeManager.shared
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @State private var configurationMode: ConfigurationMode?
    @State private var navigationPath = NavigationPath()
    @State private var isReorderMode = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Power Modes")
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .foregroundColor(.primary)
                                
                                                                 InfoTip(
                                     title: "What is Power Mode?",
                                     message: "Automatically apply custom configurations based on the app/website you are using",
                                     learnMoreURL: "https://tryvoiceink.com/docs/power-mode"
                                 )
                            }
                            
                            Text("Automate your workflows with context-aware configurations.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            if !isReorderMode {
                                Button(action: {
                                    configurationMode = .add
                                    navigationPath.append(configurationMode!)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Add Power Mode")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Button(action: { withAnimation { isReorderMode.toggle() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                                        .font(.system(size: 12, weight: .medium))
                                    Text(isReorderMode ? "Done" : "Reorder")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.windowBackgroundColor))

                // Malformed Configs Warning
                if !powerModeManager.malformedConfigs.isEmpty {
                    MalformedConfigsWarningView(
                        malformedConfigs: powerModeManager.malformedConfigs,
                        onDismiss: { powerModeManager.dismissMalformedConfigs() },
                        onRemove: { config in powerModeManager.removeMalformedConfig(config) }
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                // Content Section
                Group {
                    if isReorderMode {
                        VStack(spacing: 12) {
                            List {
                                ForEach(powerModeManager.configurations) { config in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(NSColor.controlBackgroundColor))
                                                .frame(width: 40, height: 40)
                                            Text(config.emoji)
                                                .font(.system(size: 20))
                                        }

                                        Text(config.name)
                                            .font(.system(size: 15, weight: .semibold))

                                        Spacer()

                                        HStack(spacing: 6) {
                                            if config.isDefault {
                                                Text("Default")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.accentColor))
                                                    .foregroundColor(.white)
                                            }
                                            if !config.isEnabled {
                                                Text("Disabled")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
                                                    .overlay(
                                                        Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                                    )
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(CardBackground(isSelected: false))
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 6)
                                }
                                .onMove(perform: powerModeManager.moveConfigurations)
                            }
                            .listStyle(.plain)
                            .listRowSeparator(.hidden)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.controlBackgroundColor))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    } else {
                        GeometryReader { geometry in
                            ScrollView {
                                VStack(spacing: 0) {
                                    if powerModeManager.configurations.isEmpty {
                                        VStack(spacing: 24) {
                                            Spacer()
                                                .frame(height: geometry.size.height * 0.2)
                                            
                                            VStack(spacing: 16) {
                                                Image(systemName: "square.grid.2x2.fill")
                                                    .font(.system(size: 48, weight: .regular))
                                                    .foregroundColor(.secondary.opacity(0.6))
                                                
                                                VStack(spacing: 8) {
                                                    Text("No Power Modes Yet")
                                                        .font(.system(size: 20, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    
                                                    Text("Create first power mode to automate your VoiceInk workflow based on apps/website you are using")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                        .multilineTextAlignment(.center)
                                                        .lineSpacing(2)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: geometry.size.height)
                                    } else {
                                        VStack(spacing: 0) {
                                            PowerModeConfigurationsGrid(
                                                powerModeManager: powerModeManager,
                                                onEditConfig: { config in
                                                    configurationMode = .edit(config)
                                                    navigationPath.append(configurationMode!)
                                                }
                                            )
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 20)
                                            
                                            Spacer()
                                                .frame(height: 40)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .background(Color(NSColor.controlBackgroundColor))
            .navigationDestination(for: ConfigurationMode.self) { mode in
                ConfigurationView(mode: mode, powerModeManager: powerModeManager)
            }
        }
    }
}


struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}

struct MalformedConfigsWarningView: View {
    let malformedConfigs: [MalformedPowerModeConfig]
    let onDismiss: () -> Void
    let onRemove: (MalformedPowerModeConfig) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(malformedConfigs.count) Power Mode\(malformedConfigs.count > 1 ? "s" : "") could not be loaded")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))

                    Text("Invalid configuration data will be removed when you dismiss this warning")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(malformedConfigs) { config in
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.7))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(config.name ?? "Unknown")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary.opacity(0.8))

                                Text(config.errorDescription)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            if let rawId = config.rawId {
                                Text(rawId.prefix(8) + "...")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }

                            Button(action: { onRemove(config) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Remove this malformed config")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(4)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }
}
