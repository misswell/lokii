import SwiftUI
import AppKit

// MARK: - View Extension for macOS 14+ Toolbar Compatibility
private extension View {
    @ViewBuilder
    func removeSidebarToggleIfAvailable() -> some View {
        if #available(macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}

// MARK: - Main Preferences View
struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @ObservedObject private var updater = AppUpdater.shared

    private var sidebarItems: [SidebarItem] {
        [
            SidebarItem(id: "general", title: L("prefs.tab.general"), icon: "gearshape", iconColor: Color.gray),
            SidebarItem(id: "index", title: L("prefs.tab.index"), icon: "internaldrive", iconColor: .blue, hasBadge: viewModel.isIndexDirty),
            SidebarItem(id: "privacy", title: L("prefs.tab.privacy"), icon: "hand.raised.fill", iconColor: viewModel.hasFullDiskAccess ? .green : .orange),
            SidebarItem(id: "about", title: L("prefs.tab.about"), icon: "info.circle", iconColor: .orange, hasBadge: updater.hasNewVersion)
        ]
    }

    private var currentPageTitle: String {
        switch viewModel.selectedTab {
        case "index":
            return L("prefs.tab.index")
        case "privacy":
            return L("prefs.tab.privacy")
        case "about":
            return L("prefs.tab.about")
        default:
            return L("prefs.tab.general")
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarList(items: sidebarItems, selection: Binding(
                get: { viewModel.selectedTab },
                set: { viewModel.selectedTab = $0 ?? "general" }
            ))
        } detail: {
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(currentPageTitle)
        .removeSidebarToggleIfAvailable()
        .frame(minWidth: 580, idealWidth: 620, minHeight: 480, idealHeight: 520)
        .onAppear {
            viewModel.updateFDAStatus()
            viewModel.refreshLaunchAtLoginStatus()
            viewModel.refreshCliStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.updateFDAStatus()
            viewModel.refreshCliStatus()
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch viewModel.selectedTab {
        case "index":
            PreferencesIndexPane(viewModel: viewModel)
        case "privacy":
            PreferencesPrivacyPane(viewModel: viewModel)
        case "about":
            PreferencesAboutPane()
        default:
            generalPane
        }
    }
    
    // MARK: - General Pane
    @ViewBuilder
    private var generalPane: some View {
        // Group 1: 行为
        SettingsGroup(L("prefs.section.behavior")) {
            SettingsRow(L("prefs.showInDock"), description: L("prefs.showInDock.description")) {
                Toggle("", isOn: $viewModel.showInDock)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.hideOnBlur"), description: L("prefs.hideOnBlur.description")) {
                Toggle("", isOn: $viewModel.hideOnBlur)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.rememberPosition"), description: L("prefs.rememberPosition.description")) {
                Toggle("", isOn: $viewModel.rememberPosition)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.launchAtLogin"), description: L("prefs.launchAtLogin.description")) {
                Toggle("", isOn: $viewModel.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        // Group 2: 终端与集成
        SettingsGroup(L("prefs.section.terminalAndIntegration")) {
            SettingsRow(L("prefs.defaultTerminal"), description: L("prefs.defaultTerminal.description")) {
                Menu {
                    ForEach(viewModel.availableTerminals) { item in
                        Button(action: {
                            viewModel.terminalBundleId = item.id
                        }) {
                            HStack {
                                Text(item.name)
                                if viewModel.terminalBundleId == item.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button(action: {
                        viewModel.chooseCustomTerminal(window: NSApp.keyWindow)
                    }) {
                        Text(L("prefs.defaultTerminal.chooseOther"))
                    }
                } label: {
                    Text(viewModel.selectedTerminal?.name ?? L("prefs.defaultTerminal"))
                        .font(.system(size: 12))
                }
                .menuStyle(.borderedButton)
                .fixedSize()
            }
            SettingsRowDivider()
            CliSettingRow(viewModel: viewModel)
        }
        
        // Group 3: 搜索
        SettingsGroup(L("prefs.section.search")) {
            SettingsRow(L("prefs.maxResults"), description: L("prefs.maxResults.description")) {
                HStack(spacing: 8) {
                    Text("\(viewModel.maxResults)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Stepper("", value: $viewModel.maxResults, in: 50...5000, step: 50)
                        .labelsHidden()
                }
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.globalShortcut"), description: L("prefs.globalShortcut.description")) {
                KeyboardShortcuts.Recorder(for: .toggleWindow)
            }
        }
        
        SettingsGroup(L("prefs.section.appearance")) {
            SettingsRow(L("prefs.appearance"), description: L("prefs.appearance.description")) {
                Picker("", selection: $viewModel.theme) {
                    Text(L("prefs.appearance.system")).tag(AppTheme.system)
                    Text(L("prefs.appearance.light")).tag(AppTheme.light)
                    Text(L("prefs.appearance.dark")).tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }
        }
        
        SettingsGroup(L("prefs.section.language")) {
            SettingsRow(L("prefs.language")) {
                Picker("", selection: $viewModel.language) {
                    Text(L("prefs.language.zh-Hans")).tag("zh-Hans")
                    Text(L("prefs.language.en")).tag("en")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }
        }
    }
    
    // MARK: - Index Pane
    @ViewBuilder
    private var indexPane: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Group 1: 索引目录 (Index Paths)
                    SettingsGroup(
                        L("prefs.index.group.paths"),
                        trailing: {
                            Menu {
                                Button {
                                    addIndexPathViaPanel()
                                } label: {
                                    Label(L("prefs.index.excludePaths.chooseFolder"), systemImage: "folder.badge.plus")
                                }
                                Button {
                                    presentIndexPathInputSheet()
                                } label: {
                                    Label(L("prefs.index.excludePaths.manualInput"), systemImage: "character.cursor.ibeam")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(L("prefs.index.addPath"))
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .menuStyle(.borderedButton)
                            .menuIndicator(.hidden)
                            .controlSize(.small)
                        }
                    ) {
                        VStack(spacing: 0) {
                            if viewModel.indexPaths.isEmpty {
                                Text(L("prefs.indexPaths.empty"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(Array(viewModel.indexPaths.enumerated()), id: \.element) { idx, path in
                                    if idx > 0 {
                                        SettingsRowDivider()
                                    }
                                    SettingsPathRow(icon: "folder.fill", path: path) {
                                        viewModel.indexPaths.removeAll(where: { $0 == path })
                                    }
                                }
                            }
                        }
                    }

                    // Group 2: 排除路径 (Exclude Paths)
                    SettingsGroup(
                        L("prefs.index.group.excludePaths"),
                        description: L("prefs.index.group.excludePaths.description"),
                        trailing: {
                            Menu {
                                Button {
                                    addExcludePathViaPanel()
                                } label: {
                                    Label(L("prefs.index.excludePaths.chooseFolder"), systemImage: "folder.badge.plus")
                                }
                                Button {
                                    presentExcludePathInputSheet()
                                } label: {
                                    Label(L("prefs.index.excludePaths.manualInput"), systemImage: "character.cursor.ibeam")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(L("prefs.index.addExcludePath"))
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .menuStyle(.borderedButton)
                            .menuIndicator(.hidden)
                            .controlSize(.small)
                        }
                    ) {
                        VStack(spacing: 0) {
                            // 自定义排除路径
                            if viewModel.customExcludePaths.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary.opacity(0.6))
                                        .font(.system(size: 12))
                                    Text(L("prefs.index.excludePaths.empty"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            } else {
                                ForEach(Array(viewModel.customExcludePaths.enumerated()), id: \.element) { idx, path in
                                    if idx > 0 {
                                        SettingsRowDivider()
                                    }
                                    SettingsPathRow(icon: "folder.badge.minus", path: path) {
                                        viewModel.excludePaths.removeAll(where: { $0 == path })
                                    }
                                }
                            }

                            // 系统与运行环境默认排除预设 (折叠展示)
                            if !viewModel.presetExcludePaths.isEmpty {
                                SettingsRowDivider()

                                DisclosureGroup(isExpanded: $isPresetsExpanded) {
                                    FlowLayout(spacing: 6) {
                                        ForEach(viewModel.presetExcludePaths, id: \.self) { path in
                                            PillTagView(title: path) {
                                                viewModel.excludePaths.removeAll(where: { $0 == path })
                                            }
                                        }
                                    }
                                    .padding(.top, 6)
                                    .padding(.bottom, 4)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .foregroundStyle(Color.accentColor)
                                            .font(.system(size: 11))
                                        Text(String(format: L("prefs.index.excludePaths.systemPresets.count"), viewModel.presetExcludePaths.count))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    // Group 3: 排除名称规则 (Exclude Patterns - Pill Tags)
                    SettingsGroup(
                        L("prefs.index.group.excludes"),
                        description: L("prefs.excludePatterns.description"),
                        trailing: {
                            Button {
                                presentExcludePatternSheet(
                                    title: L("prefs.excludePatterns.editor.addTitle"),
                                    initialValue: ""
                                ) { newValue in
                                    guard let newValue = newValue else { return }
                                    if !viewModel.excludePatterns.contains(newValue) {
                                        viewModel.excludePatterns.append(newValue)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(L("prefs.index.excludePatterns.add"))
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    ) {
                        VStack(spacing: 0) {
                            // 自定义排除规则
                            if viewModel.customExcludePatterns.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag")
                                        .foregroundStyle(.secondary.opacity(0.6))
                                        .font(.system(size: 12))
                                    Text(L("prefs.index.excludePatterns.empty"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            } else {
                                FlowLayout(spacing: 6) {
                                    ForEach(viewModel.customExcludePatterns, id: \.self) { pattern in
                                        PillTagView(title: pattern) {
                                            viewModel.excludePatterns.removeAll(where: { $0 == pattern })
                                        }
                                    }
                                    AddPillButton(title: L("prefs.index.excludePatterns.add")) {
                                        presentExcludePatternSheet(
                                            title: L("prefs.excludePatterns.editor.addTitle"),
                                            initialValue: ""
                                        ) { newValue in
                                            guard let newValue = newValue else { return }
                                            if !viewModel.excludePatterns.contains(newValue) {
                                                viewModel.excludePatterns.append(newValue)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }

                            // 开发与构建缓存默认排除预设 (折叠展示)
                            if !viewModel.presetExcludePatterns.isEmpty {
                                SettingsRowDivider()

                                DisclosureGroup(isExpanded: $isPatternPresetsExpanded) {
                                    FlowLayout(spacing: 6) {
                                        ForEach(viewModel.presetExcludePatterns, id: \.self) { pattern in
                                            PillTagView(title: pattern) {
                                                viewModel.excludePatterns.removeAll(where: { $0 == pattern })
                                            }
                                        }
                                    }
                                    .padding(.top, 6)
                                    .padding(.bottom, 4)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .foregroundStyle(Color.accentColor)
                                            .font(.system(size: 11))
                                        Text(String(format: L("prefs.index.excludePatterns.systemPresets.count"), viewModel.presetExcludePatterns.count))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    // Group 4: 扫描选项
                    SettingsGroup(L("prefs.index.group.options")) {
                        SettingsRow(L("prefs.includeHidden"), description: L("prefs.includeHidden.description")) {
                            Toggle("", isOn: $viewModel.includeHidden)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        SettingsRowDivider()
                        SettingsRow(L("prefs.networkRescan"), description: L("prefs.networkRescan.description")) {
                            HStack(spacing: 8) {
                                Text(viewModel.networkRescanMinutes == 0
                                     ? L("prefs.networkRescan.off")
                                     : String(format: L("prefs.networkRescan.minutes"), viewModel.networkRescanMinutes))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                Stepper("", value: $viewModel.networkRescanMinutes, in: 0...120)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            
            // Fixed Bottom Action Bar
            indexActionBar
        }
    }
    
    // MARK: - Privacy Pane
    @ViewBuilder
    private var privacyPane: some View {
        SettingsGroup(L("prefs.privacy.fullDiskAccess")) {
            SettingsRow(
                viewModel.hasFullDiskAccess ? L("prefs.privacy.status.granted") : L("prefs.privacy.status.missing")
            ) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.hasFullDiskAccess ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(viewModel.hasFullDiskAccess ? L("prefs.privacy.badge.granted") : L("prefs.privacy.badge.missing"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(viewModel.hasFullDiskAccess ? .green : .orange)
                }
            }
            
            SettingsRowDivider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.hasFullDiskAccess ? L("prefs.privacy.status.granted.description") : L("prefs.privacy.status.missing.description"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !viewModel.hasFullDiskAccess {
                    HStack(spacing: 12) {
                        Button {
                            FDAGuideWindowController.show()
                        } label: {
                            Text(L("prefs.privacy.viewGuide"))
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            FDAGuideWindowController.openSystemSettingsPage()
                        } label: {
                            Text(L("prefs.privacy.openSettings"))
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(L("prefs.privacy.rebuildHint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - About Pane
    @ViewBuilder
    private var aboutPane: some View {
        // Header
        VStack(spacing: 8) {
            if let appIcon = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "magnifyingglass.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            
            Text("Lokii")
                .font(.title2)
                .bold()
            
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            if !version.isEmpty {
                Text("v\(version)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Text(L("about.tagline"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        
        // Update Section
        SettingsGroup(L("prefs.about.update.section")) {
            SettingsRow(L("prefs.about.update.automatic")) {
                Toggle("", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(L("prefs.about.update.automatic"))
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.about.update.status")) {
                HStack(spacing: 8) {
                    if updater.isChecking {
                        ProgressView()
                            .controlSize(.small)
                        Text(L("prefs.about.update.checking"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else if let error = updater.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else if updater.lastCheckTime != nil {
                        Text(L(updater.hasNewVersion ? "prefs.about.update.found" : "prefs.about.update.latest"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Button(L("prefs.about.update.checkNow")) {
                        updater.checkForUpdates(isUserInitiated: true)
                    }
                    .disabled(updater.isChecking)
                    .controlSize(.small)
                }
            }
            if updater.errorMessage != nil {
                SettingsRow(L("prefs.about.update.manualDownload")) {
                    Button(L("prefs.about.update.download")) {
                        updater.openDownloadPage()
                    }
                    .controlSize(.small)
                }
            }
        }
        
        // Info Group
        SettingsGroup {
            SettingsRow(L("prefs.about.architecture")) {
                Text(L("prefs.about.architecture.value"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.about.license")) {
                Text(L("prefs.about.license.value"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            SettingsRowDivider()
            SettingsRow(L("prefs.about.source")) {
                Button(L("prefs.about.source.action")) {
                    if let url = URL(string: "https://github.com/misswell/lokii") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
        }
    }
    
    // MARK: - Bottom Action Bar (Index Settings only)
    private var indexActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if viewModel.isIndexDirty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 11))
                        Text(L("prefs.index.unsaved"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                Button {
                    viewModel.restoreIndexDefaults()
                } label: {
                    Text(L("prefs.resetToDefaults"))
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIndexDirty && viewModel.isDefaultIndexState)
                
                Button {
                    _ = viewModel.saveIndexChanges()
                } label: {
                    Text(L("prefs.save"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(viewModel.isIndexDirty ? Color.accentColor : Color.primary.opacity(0.05))
                        .foregroundColor(viewModel.isIndexDirty ? .white : .secondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIndexDirty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    // MARK: - Helpers
    private var currentWindow: NSWindow? {
        if let window = window { return window }
        return NSApp.windows.first(where: { $0.frameAutosaveName == "LokiiPreferencesWindow" }) ?? NSApp.keyWindow
    }

    private func normalizePathString(_ raw: String) -> String {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("~/") {
            // Keep tilde
        } else if path == NSHomeDirectory() {
            path = "~"
        } else if path.hasPrefix(NSHomeDirectory() + "/") {
            path = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
        // Remove trailing slashes if longer than 1 character
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private func addExcludePathViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        
        if let targetWindow = currentWindow {
            panel.beginSheetModal(for: targetWindow) { response in
                guard response == .OK else { return }
                for url in panel.urls {
                    let normalized = normalizePathString(url.path)
                    if !viewModel.excludePaths.contains(normalized) {
                        viewModel.excludePaths.append(normalized)
                    }
                }
            }
        }
    }

    private func checkPathExistenceAndConfirm(path: String, onConfirmed: @escaping () -> Void) {
        var isDir: ObjCBool = false
        let expanded = (path as NSString).expandingTildeInPath
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
        if exists {
            onConfirmed()
            return
        }

        let confirmAlert = NSAlert()
        confirmAlert.messageText = L("prefs.index.pathConfirm.title")
        confirmAlert.informativeText = String(format: L("prefs.index.pathConfirm.message"), path)
        let confirmBtn = confirmAlert.addButton(withTitle: L("prefs.index.pathConfirm.addAnyway"))
        confirmBtn.keyEquivalent = "\r"
        confirmAlert.addButton(withTitle: L("prefs.index.pathConfirm.cancel"))

        if let targetWindow = currentWindow {
            confirmAlert.beginSheetModal(for: targetWindow) { resp in
                if resp == .alertFirstButtonReturn {
                    onConfirmed()
                }
            }
        } else {
            if confirmAlert.runModal() == .alertFirstButtonReturn {
                onConfirmed()
            }
        }
    }

    private func presentExcludePathInputSheet() {
        let alert = NSAlert()
        alert.messageText = L("prefs.index.excludePaths.inputTitle")
        alert.informativeText = L("prefs.index.excludePaths.inputMessage")

        let confirmButton = alert.addButton(withTitle: L("prefs.excludePatterns.editor.confirm"))
        confirmButton.keyEquivalent = "\r"
        alert.addButton(withTitle: L("prefs.excludePatterns.editor.cancel"))

        let field = NSTextField(string: "")
        field.placeholderString = L("prefs.index.excludePaths.inputPlaceholder")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field

        if let targetWindow = currentWindow {
            alert.beginSheetModal(for: targetWindow) { response in
                guard response == .alertFirstButtonReturn else { return }
                let normalized = normalizePathString(field.stringValue)
                guard !normalized.isEmpty else { return }
                checkPathExistenceAndConfirm(path: normalized) {
                    if !viewModel.excludePaths.contains(normalized) {
                        viewModel.excludePaths.append(normalized)
                    }
                }
            }
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }

    private func addIndexPathViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        
        if let targetWindow = currentWindow {
            panel.beginSheetModal(for: targetWindow) { response in
                guard response == .OK else { return }
                for url in panel.urls {
                    let normalized = normalizePathString(url.path)
                    if !viewModel.indexPaths.contains(normalized) {
                        viewModel.indexPaths.append(normalized)
                    }
                }
            }
        }
    }

    private func presentIndexPathInputSheet() {
        let alert = NSAlert()
        alert.messageText = L("prefs.index.indexPaths.inputTitle")
        alert.informativeText = L("prefs.index.indexPaths.inputMessage")

        let confirmButton = alert.addButton(withTitle: L("prefs.excludePatterns.editor.confirm"))
        confirmButton.keyEquivalent = "\r"
        alert.addButton(withTitle: L("prefs.excludePatterns.editor.cancel"))

        let field = NSTextField(string: "")
        field.placeholderString = L("prefs.index.indexPaths.inputPlaceholder")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field

        if let targetWindow = currentWindow {
            alert.beginSheetModal(for: targetWindow) { response in
                guard response == .alertFirstButtonReturn else { return }
                let normalized = normalizePathString(field.stringValue)
                guard !normalized.isEmpty else { return }
                checkPathExistenceAndConfirm(path: normalized) {
                    if !viewModel.indexPaths.contains(normalized) {
                        viewModel.indexPaths.append(normalized)
                    }
                }
            }
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
    }
    
    private func presentExcludePatternSheet(
        title: String,
        initialValue: String,
        completion: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = L("prefs.excludePatterns.editor.message")

        let confirmButton = alert.addButton(withTitle: L("prefs.excludePatterns.editor.confirm"))
        confirmButton.keyEquivalent = "\r"
        alert.addButton(withTitle: L("prefs.excludePatterns.editor.cancel"))

        let field = NSTextField(string: initialValue)
        field.placeholderString = L("prefs.excludePatterns.editor.placeholder")
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field

        if let targetWindow = currentWindow {
            alert.beginSheetModal(for: targetWindow) { response in
                guard response == .alertFirstButtonReturn else {
                    completion(nil)
                    return
                }

                let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(trimmed.isEmpty ? nil : trimmed)
            }
            
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                field.selectText(nil)
            }
        } else {
            completion(nil)
        }
    }
}
