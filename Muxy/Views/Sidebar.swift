import SwiftUI

enum SidebarLayout {
    static let collapsedWidth: CGFloat = 44
    static let expandedWidth: CGFloat = 220
    static let width: CGFloat = 44

    static func resolvedWidth(expanded: Bool) -> CGFloat {
        expanded ? expandedWidth : collapsedWidth
    }
}

struct Sidebar: View {
    @Environment(AppState.self) private var appState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(WorktreeStore.self) private var worktreeStore
    @State private var dragState = ProjectDragState()
    @State private var expanded = UserDefaults.standard.bool(forKey: "muxy.sidebarExpanded")

    var body: some View {
        VStack(spacing: 0) {
            projectList
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()

            SidebarFooter(expanded: expanded)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .frame(width: SidebarLayout.resolvedWidth(expanded: expanded))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar")
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            toggleExpanded()
        }
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            expanded.toggle()
        }
        UserDefaults.standard.set(expanded, forKey: "muxy.sidebarExpanded")
    }

    private var addButton: some View {
        AddProjectButton(expanded: expanded) {
            ProjectOpenService.openProject(
                appState: appState,
                projectStore: projectStore,
                worktreeStore: worktreeStore
            )
        }
        .help(shortcutTooltip("Add Project", for: .openProject))
    }

    private var projectList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: expanded ? 2 : 4) {
                ForEach(Array(projectStore.projects.enumerated()), id: \.element.id) { index, project in
                    Group {
                        if expanded {
                            ExpandedProjectRow(
                                project: project,
                                shortcutIndex: index < 9 ? index + 1 : nil,
                                isAnyDragging: dragState.draggedID != nil,
                                onSelect: { select(project) },
                                onRemove: { remove(project) },
                                onRename: { projectStore.rename(id: project.id, to: $0) },
                                onSetLogo: { projectStore.setLogo(id: project.id, to: $0) },
                                onSetIconColor: { projectStore.setIconColor(id: project.id, to: $0) }
                            )
                        } else {
                            ProjectRow(
                                project: project,
                                shortcutIndex: index < 9 ? index + 1 : nil,
                                isAnyDragging: dragState.draggedID != nil,
                                onSelect: { select(project) },
                                onRemove: { remove(project) },
                                onRename: { projectStore.rename(id: project.id, to: $0) },
                                onSetLogo: { projectStore.setLogo(id: project.id, to: $0) },
                                onSetIconColor: { projectStore.setIconColor(id: project.id, to: $0) }
                            )
                        }
                    }
                    .background {
                        if dragState.draggedID != nil {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: UUIDFramePreferenceKey<SidebarFrameTag>.self,
                                    value: [project.id: geo.frame(in: .named("sidebar"))]
                                )
                            }
                        }
                    }
                    .gesture(projectDragGesture(for: project))
                }
                addButton
            }
            .padding(.horizontal, expanded ? 6 : 8)
            .padding(.vertical, 4)
            .onPreferenceChange(UUIDFramePreferenceKey<SidebarFrameTag>.self) { frames in
                guard dragState.draggedID != nil else { return }
                dragState.frames = frames
            }
        }
        .coordinateSpace(name: "sidebar")
    }

    private func shortcutTooltip(_ name: String, for action: ShortcutAction) -> String {
        "\(name) (\(KeyBindingStore.shared.combo(for: action).displayString))"
    }

    private func projectDragGesture(for project: Project) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("sidebar"))
            .onChanged { value in
                if dragState.draggedID == nil {
                    dragState.draggedID = project.id
                    dragState.lastReorderTargetID = nil
                }
                reorderIfNeeded(at: value.location)
            }
            .onEnded { _ in
                withAnimation(.easeInOut(duration: 0.15)) {
                    dragState.draggedID = nil
                    dragState.frames = [:]
                    dragState.lastReorderTargetID = nil
                }
            }
    }

    private func select(_ project: Project) {
        worktreeStore.ensurePrimary(for: project)
        guard let worktree = worktreeStore.preferred(
            for: project.id,
            matching: appState.activeWorktreeID[project.id]
        )
        else { return }
        appState.selectProject(project, worktree: worktree)
    }

    private func remove(_ project: Project) {
        let capturedProject = project
        let knownWorktrees = worktreeStore.list(for: project.id)
        Task.detached {
            await WorktreeStore.cleanupOnDisk(for: capturedProject, knownWorktrees: knownWorktrees)
        }
        appState.removeProject(project.id)
        projectStore.remove(id: project.id)
        worktreeStore.removeProject(project.id)
    }

    private func reorderIfNeeded(at location: CGPoint) {
        guard let draggedID = dragState.draggedID else { return }
        var hoveredTargetID: UUID?

        for (id, frame) in dragState.frames where id != draggedID {
            guard frame.contains(location) else { continue }
            hoveredTargetID = id
            guard dragState.lastReorderTargetID != id else { return }

            guard let sourceIndex = projectStore.projects.firstIndex(where: { $0.id == draggedID }),
                  let destIndex = projectStore.projects.firstIndex(where: { $0.id == id })
            else { return }

            dragState.lastReorderTargetID = id
            let offset = destIndex > sourceIndex ? destIndex + 1 : destIndex
            withAnimation(.easeInOut(duration: 0.15)) {
                projectStore.reorder(
                    fromOffsets: IndexSet(integer: sourceIndex), toOffset: offset
                )
            }
            return
        }

        if hoveredTargetID == nil {
            dragState.lastReorderTargetID = nil
        }
    }
}

private struct ProjectDragState {
    var draggedID: UUID?
    var frames: [UUID: CGRect] = [:]
    var lastReorderTargetID: UUID?
}

private struct AddProjectButton: View {
    var expanded: Bool = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            if expanded {
                expandedLayout
            } else {
                collapsedLayout
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("Add Project")
    }

    private var collapsedLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(MuxyTheme.hover)
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(hovered ? MuxyTheme.accent : MuxyTheme.fgMuted)
        }
        .frame(width: 32, height: 32)
        .padding(3)
    }

    private var expandedLayout: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(MuxyTheme.surface)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hovered ? MuxyTheme.accent : MuxyTheme.fgMuted)
            }
            .frame(width: 24, height: 24)

            Text("Add Project")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovered ? MuxyTheme.accent : MuxyTheme.fgMuted)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovered ? MuxyTheme.hover : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SidebarFooter: View {
    var expanded: Bool = false
    @AppStorage(AIUsageSettingsStore.usageEnabledKey) private var usageEnabled = false
    @AppStorage(AIUsageSettingsStore.usageDisplayModeKey) private var usageDisplayModeRaw = AIUsageSettingsStore.defaultUsageDisplayMode
        .rawValue
    @State private var showThemePicker = false
    @State private var showNotifications = false
    @State private var showAIUsagePopover = false
    @State private var usageService = AIUsageService.shared

    private var usageDisplayMode: AIUsageDisplayMode {
        AIUsageDisplayMode(rawValue: usageDisplayModeRaw) ?? AIUsageSettingsStore.defaultUsageDisplayMode
    }

    private let usageRefreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var notificationStore: NotificationStore { NotificationStore.shared }

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                expandedFooter
            } else {
                collapsedFooter
            }
        }
        .task {
            await usageService.refreshIfNeeded()
        }
        .onReceive(usageRefreshTimer) { _ in
            Task {
                await usageService.refreshIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleThemePicker)) { _ in
            showThemePicker.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleNotificationPanel)) { _ in
            showNotifications.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAIUsage)) { _ in
            guard usageEnabled else { return }
            showAIUsagePopover.toggle()
        }
        .onChange(of: usageEnabled) { _, enabled in
            if !enabled {
                showAIUsagePopover = false
            }
        }
    }

    private func postToggleSidebar() {
        NotificationCenter.default.post(name: .toggleSidebar, object: nil)
    }

    private var sidebarToggleLabel: String {
        expanded ? "Collapse Sidebar" : "Expand Sidebar"
    }

    private var sidebarToggleIcon: String {
        "sidebar.left"
    }

    private var notificationBellIcon: String {
        notificationStore.unreadCount > 0 ? "bell.badge" : "bell"
    }

    private var previewProviderDisplay: (percent: Int, iconName: String)? {
        guard let snapshot = usageService.previewProviderSnapshot,
              case .available = snapshot.state
        else { return nil }

        let usedPercent = max(0, min(100, snapshot.rows.compactMap(\.percent).max() ?? 0))
        let displayPercent: Double = switch usageDisplayMode {
        case .used:
            usedPercent
        case .remaining:
            max(0, min(100, 100 - usedPercent))
        }

        return (Int(displayPercent.rounded()), snapshot.providerIconName)
    }

    private var previewProviderPercentLabel: String? {
        guard let display = previewProviderDisplay else { return nil }
        return "\(max(0, min(100, display.percent)))%"
    }

    private var aiUsageButton: some View {
        AIUsagePreviewButton(
            display: previewProviderDisplay,
            percentLabel: previewProviderPercentLabel,
            expanded: expanded,
            onTap: { showAIUsagePopover.toggle() }
        )
        .popover(isPresented: $showAIUsagePopover) {
            AIUsagePanel(
                snapshots: usageService.snapshots,
                isRefreshing: usageService.isRefreshing,
                lastRefreshDate: usageService.lastRefreshDate,
                onRefresh: refreshUsage
            )
        }
        .help("AI Usage (\(KeyBindingStore.shared.combo(for: .toggleAIUsage).displayString))")
    }

    private var collapsedFooter: some View {
        VStack(spacing: 4) {
            if usageEnabled {
                aiUsageButton
            }
            IconButton(symbol: notificationBellIcon, accessibilityLabel: "Notifications") { showNotifications.toggle() }
                .help("Notifications")
                .popover(isPresented: $showNotifications) {
                    NotificationPanel(onDismiss: { showNotifications = false })
                }
            IconButton(symbol: "paintpalette", accessibilityLabel: "Theme Picker") { showThemePicker.toggle() }
                .help("Theme Picker (\(KeyBindingStore.shared.combo(for: .toggleThemePicker).displayString))")
                .popover(isPresented: $showThemePicker) { ThemePicker() }
            IconButton(symbol: sidebarToggleIcon, accessibilityLabel: sidebarToggleLabel) { postToggleSidebar() }
                .help("\(sidebarToggleLabel) (\(KeyBindingStore.shared.combo(for: .toggleSidebar).displayString))")
        }
        .padding(.bottom, 8)
    }

    private var expandedFooter: some View {
        HStack(spacing: 4) {
            IconButton(symbol: sidebarToggleIcon, accessibilityLabel: sidebarToggleLabel) { postToggleSidebar() }
                .help("\(sidebarToggleLabel) (\(KeyBindingStore.shared.combo(for: .toggleSidebar).displayString))")

            Spacer()

            if usageEnabled {
                aiUsageButton
            }
            IconButton(symbol: notificationBellIcon, accessibilityLabel: "Notifications") { showNotifications.toggle() }
                .help("Notifications")
                .popover(isPresented: $showNotifications) {
                    NotificationPanel(onDismiss: { showNotifications = false })
                }
            IconButton(symbol: "paintpalette", accessibilityLabel: "Theme Picker") { showThemePicker.toggle() }
                .help("Theme Picker (\(KeyBindingStore.shared.combo(for: .toggleThemePicker).displayString))")
                .popover(isPresented: $showThemePicker) { ThemePicker() }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func refreshUsage() {
        Task {
            await usageService.refresh(force: true)
        }
    }
}

private struct AIUsagePreviewButton: View {
    let display: (percent: Int, iconName: String)?
    let percentLabel: String?
    let expanded: Bool
    let onTap: () -> Void

    @State private var hovered = false

    private var foreground: Color {
        hovered ? MuxyTheme.fg : MuxyTheme.fgMuted
    }

    var body: some View {
        Button(action: onTap) {
            Group {
                if expanded {
                    expandedLabel
                } else {
                    compactLabel
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("AI Usage")
    }

    private var expandedLabel: some View {
        HStack(spacing: 4) {
            iconGlyph
            if let percentLabel {
                Text(percentLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(height: 24)
    }

    private var compactLabel: some View {
        iconGlyph
            .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var iconGlyph: some View {
        if let display {
            ProviderIconView(iconName: display.iconName, size: 14, style: .monochrome(foreground))
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(foreground)
        }
    }
}

private struct AIUsagePanel: View {
    let snapshots: [AIProviderUsageSnapshot]
    let isRefreshing: Bool
    let lastRefreshDate: Date?
    let onRefresh: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
                Text("AI Usage")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MuxyTheme.fgMuted)
                Spacer()
                Button(action: onRefresh) {
                    Group {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .frame(width: 10, height: 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MuxyTheme.fgMuted)
                .disabled(isRefreshing)
                .help("Refresh usage")
                if let lastRefreshDate {
                    Text(Self.relativeFormatter.localizedString(for: lastRefreshDate, relativeTo: Date()))
                        .font(.system(size: 9))
                        .foregroundStyle(MuxyTheme.fgDim)
                }
            }

            if snapshots.isEmpty {
                Text(isRefreshing ? "Refreshing usage data..." : "No usage data yet.")
                    .font(.system(size: 10))
                    .foregroundStyle(MuxyTheme.fgDim)
            }

            if !snapshots.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshots) { snapshot in
                        AIProviderUsageView(snapshot: snapshot)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(MuxyTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AIProviderUsageView: View {
    let snapshot: AIProviderUsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProviderIconView(iconName: snapshot.providerIconName, size: 12, style: .monochrome(MuxyTheme.fg))
                Text(snapshot.providerName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MuxyTheme.fg)
            }

            switch snapshot.state {
            case .available:
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(snapshot.rows) { row in
                        AIUsageMetricRowView(row: row, fetchedAt: snapshot.fetchedAt)
                    }
                }
            case let .unavailable(message),
                 let .error(message):
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(MuxyTheme.fgDim)
            }
        }
    }
}

private struct AIUsageMetricRowView: View {
    let row: AIUsageMetricRow
    let fetchedAt: Date

    @AppStorage(AIUsageSettingsStore.usageDisplayModeKey) private var usageDisplayModeRaw = AIUsageSettingsStore.defaultUsageDisplayMode
        .rawValue

    private var usageDisplayMode: AIUsageDisplayMode {
        AIUsageDisplayMode(rawValue: usageDisplayModeRaw) ?? AIUsageSettingsStore.defaultUsageDisplayMode
    }

    private var paceResult: AIUsagePaceResult? {
        guard let percentUsed = row.percent,
              let resetsAt = row.resetDate,
              let duration = row.periodDuration
        else { return nil }

        return AIUsagePaceCalculator.compute(
            usedPercent: percentUsed,
            resetsAt: resetsAt,
            periodDuration: duration,
            now: fetchedAt
        )
    }

    private var paceIndicatorColor: Color {
        guard let paceResult else { return .clear }
        switch paceResult.status {
        case .ahead:
            return .green
        case .onTrack:
            return .yellow
        case .behind:
            return .red
        }
    }

    private var paceDetailText: String? {
        guard let paceResult else { return nil }

        if let eta = paceResult.runsOutIn {
            return "Runs out in \(AIUsagePaceCalculator.formatDuration(eta))"
        }

        if let deficit = paceResult.deficitPercent, deficit > 0 {
            return "\(Int(deficit))% in deficit"
        }

        switch usageDisplayMode {
        case .used:
            return "\(Int(paceResult.projectedUsedPercentAtReset))% used at reset"
        case .remaining:
            return "\(Int(paceResult.projectedLeftPercentAtReset))% left at reset"
        }
    }

    private var displayDetail: String? {
        guard let detail = row.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty else {
            return nil
        }

        switch usageDisplayMode {
        case .used:
            if let converted = convertRemainingFractionToUsed(detail) {
                return converted
            }
            if let converted = convertRemainingPercentToUsed(detail) {
                return converted
            }
            return detail
        case .remaining:
            if let converted = convertUsedFractionToRemaining(detail) {
                return converted
            }
            if let converted = convertUsedPercentToRemaining(detail) {
                return converted
            }
            return detail
        }
    }

    private func convertUsedFractionToRemaining(_ detail: String) -> String? {
        guard let match = fractionMatch(from: detail), !match.isRemainingLabel else { return nil }
        let remaining = max(0, match.total - match.left)
        return "\(AIUsageParserSupport.formatNumber(remaining))/\(AIUsageParserSupport.formatNumber(match.total))"
    }

    private func convertRemainingFractionToUsed(_ detail: String) -> String? {
        guard let match = fractionMatch(from: detail), match.isRemainingLabel else { return nil }
        let used = max(0, match.total - match.left)
        return "\(AIUsageParserSupport.formatNumber(used))/\(AIUsageParserSupport.formatNumber(match.total))"
    }

    private func convertUsedPercentToRemaining(_ detail: String) -> String? {
        guard let used = percentMatch(from: detail, modeToken: "used") else { return nil }
        let remaining = max(0, min(100, 100 - used))
        return "\(AIUsageParserSupport.formatNumber(remaining))% left"
    }

    private func convertRemainingPercentToUsed(_ detail: String) -> String? {
        guard let remaining = percentMatch(from: detail, modeToken: "left|remaining") else { return nil }
        let used = max(0, min(100, 100 - remaining))
        return "\(AIUsageParserSupport.formatNumber(used))% used"
    }

    private struct FractionMatch {
        let left: Double
        let total: Double
        let isRemainingLabel: Bool
    }

    private func fractionMatch(from detail: String) -> FractionMatch? {
        let pattern = #"^\s*([0-9]+(?:\.[0-9]+)?)\s*/\s*([0-9]+(?:\.[0-9]+)?)(?:\s*(left|remaining))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(detail.startIndex ..< detail.endIndex, in: detail)
        guard let match = regex.firstMatch(in: detail, options: [], range: range),
              match.numberOfRanges >= 4,
              let leftRange = Range(match.range(at: 1), in: detail),
              let totalRange = Range(match.range(at: 2), in: detail),
              let left = Double(detail[leftRange]),
              let total = Double(detail[totalRange]),
              total > 0
        else {
            return nil
        }

        let remainingRange = match.range(at: 3)
        let isRemainingLabel = remainingRange.location != NSNotFound
        return FractionMatch(left: left, total: total, isRemainingLabel: isRemainingLabel)
    }

    private func percentMatch(from detail: String, modeToken: String) -> Double? {
        let pattern = "^\\s*([0-9]+(?:\\.[0-9]+)?)%\\s*(?:" + modeToken + ")\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(detail.startIndex ..< detail.endIndex, in: detail)
        guard let match = regex.firstMatch(in: detail, options: [], range: range),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: detail),
              let value = Double(detail[valueRange])
        else {
            return nil
        }
        return value
    }

    private var displayPercent: Double? {
        guard let percent = row.percent else { return nil }
        let clamped = max(0, min(100, percent))
        switch usageDisplayMode {
        case .used:
            return clamped
        case .remaining:
            return max(0, min(100, 100 - clamped))
        }
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(row.label)
                    .font(.system(size: 10))
                    .foregroundStyle(MuxyTheme.fgMuted)

                if paceDetailText != nil {
                    Circle()
                        .fill(paceIndicatorColor)
                        .frame(width: 5, height: 5)
                }
                Spacer()
                if let percent = displayPercent {
                    Text("\(Int(percent.rounded()))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(MuxyTheme.fg)
                }
                if let detail = displayDetail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(MuxyTheme.fgDim)
                }
            }

            if let percent = displayPercent {
                ProgressView(value: percent, total: 100)
                    .tint(MuxyTheme.accent)
                    .controlSize(.mini)
            }

            if let resetDate = row.resetDate {
                HStack(spacing: 6) {
                    Text("Resets \(Self.resetFormatter.string(from: resetDate))")
                        .font(.system(size: 9))
                        .foregroundStyle(MuxyTheme.fgDim)

                    Spacer(minLength: 0)

                    if let paceDetailText {
                        Text(paceDetailText)
                            .font(.system(size: 9))
                            .foregroundStyle(MuxyTheme.fgDim)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
