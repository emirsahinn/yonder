//
//  WorkItemPickerSheet.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// Sheet displaying previously used work items/subjects with live search,
/// last-used sorting, quick-add functionality, and swipe management.
struct WorkItemPickerSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("app_language") private var appLanguage: String = "en"

    private var isIPad: Bool { hSizeClass == .regular }
    private var hPad: CGFloat { isIPad ? 60 : 20 }

    @Query(sort: \Subject.lastUsedDate, order: .reverse) private var savedSubjects: [Subject]
    @Query private var allSessions: [FocusSession]

    /// The work item selected by the user. Optional binding (can be .constant(nil) when opened from Settings).
    @Binding var selectedWorkItem: String?

    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool

    // Delete & Rename states
    @State private var subjectToDelete: Subject? = nil
    @State private var showDeleteConfirmation: Bool = false

    @State private var subjectToRename: Subject? = nil
    @State private var renameText: String = ""
    @State private var showRenameAlert: Bool = false

    @State private var showWorkItemManagementSheet: Bool = false
    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false
    @State private var showPaywallSheet: Bool = false

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Filtered list based on search query.
    private var filteredSubjects: [Subject] {
        let activeSubjects = savedSubjects.filter { !$0.isArchived }
        if trimmedQuery.isEmpty {
            return activeSubjects
        } else {
            return activeSubjects.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
    }

    /// Checks if there is an exact case-insensitive match for the typed query among saved subjects.
    private var hasExactMatch: Bool {
        guard !trimmedQuery.isEmpty else { return false }
        return savedSubjects.filter { !$0.isArchived }.contains {
            $0.name.localizedCaseInsensitiveCompare(trimmedQuery) == .orderedSame
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header Handle & Dismiss Button ────────────────────────
                headerView

                // ── Search Bar ────────────────────────────────────────────
                searchBarView
                    .padding(.horizontal, hPad)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // ── Work Items List with Swipe Actions ────────────────────
                List {
                    // Top Action: Go to My Work Areas
                    Button {
                        showWorkItemManagementSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(white: 0.9))

                            Text(appLanguage == "tr" ? "Çalışmalarım'a Git" : "Go to My Work Areas")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(white: 0.95))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.4))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color(white: 0.22), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: hPad, bottom: 8, trailing: hPad))
                    .listRowSeparator(.hidden)

                    // Matching / Filtered Subjects List
                    ForEach(filteredSubjects) { subject in
                        workItemRow(subject: subject) {
                            selectExistingSubject(subject)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: hPad, bottom: 4, trailing: hPad))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                subjectToDelete = subject
                                showDeleteConfirmation = true
                            } label: {
                                Label(appLanguage == "tr" ? "Sil" : "Delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                subjectToRename = subject
                                renameText = subject.name
                                showRenameAlert = true
                            } label: {
                                Label(appLanguage == "tr" ? "Düzenle" : "Edit", systemImage: "pencil")
                            }
                            .tint(Color(white: 0.3))
                        }
                    }

                    // Guidance when typed query has no match
                    if !trimmedQuery.isEmpty && !hasExactMatch {
                        VStack(spacing: 10) {
                            Text(appLanguage == "tr" ? "Eşleşen çalışma bulunamadı." : "No matching work area found.")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(Color(white: 0.45))

                            Button {
                                showWorkItemManagementSheet = true
                            } label: {
                                Text(appLanguage == "tr" ? "Yeni Çalışma Oluştur" : "Create New Work Area")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color.white))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: hPad, bottom: 4, trailing: hPad))
                        .listRowSeparator(.hidden)
                    }

                    // Empty State Info when no subjects exist yet and query is empty
                    if savedSubjects.filter({ !$0.isArchived }).isEmpty && trimmedQuery.isEmpty {
                        emptyStateInfo
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 16, leading: hPad, bottom: 16, trailing: hPad))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: isIPad ? 680 : .infinity)
        }
        .sheet(isPresented: $showWorkItemManagementSheet) {
            WorkItemManagementView()
        }
        .alert(appLanguage == "tr" ? "Çalışma Alanını Düzenle" : "Edit Work Area", isPresented: $showRenameAlert) {
            TextField(appLanguage == "tr" ? "Çalışma Adı" : "Work Area Name", text: $renameText)
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {
                subjectToRename = nil
                renameText = ""
            }
            Button(appLanguage == "tr" ? "Kaydet" : "Save") {
                performRename()
            }
        } message: {
            Text(appLanguage == "tr" ? "Bu değişiklik geçmiş raporlarına da yansır." : "This change also updates your past reports.")
        }
        .confirmationDialog(
            appLanguage == "tr" ? "Çalışmayı Sil" : "Delete Work Area",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: subjectToDelete
        ) { subject in
            Button(appLanguage == "tr" ? "Sil" : "Delete", role: .destructive) {
                performDelete(subject)
            }
            Button(appLanguage == "tr" ? "Vazgeç" : "Cancel", role: .cancel) {}
        } message: { _ in
            Text(appLanguage == "tr" ? "Bu çalışma yeni oturumlarda görünmez. Geçmiş raporların korunur." : "This work area will be hidden from new sessions. Your report history stays intact.")
        }
        .onAppear {
            WorkItemMaintenanceHelper.cleanAndNormalizeSubjects(
                modelContext: modelContext,
                savedSubjects: savedSubjects,
                allSessions: allSessions
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywallSheet) {
            YonderPaywallSheetView {
                isPremiumUser = true
                showPaywallSheet = false
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            // Drag Indicator
            Capsule()
                .fill(Color(white: 0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack {
                Text(appLanguage == "tr" ? "Çalışma Alanı Seç" : "Select Work Area")
                    .font(.system(size: isIPad ? 19 : 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.9))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isIPad ? 23 : 20))
                        .foregroundStyle(Color(white: 0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, hPad)
            .padding(.top, 4)
        }
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.45))

            TextField("", text: $searchQuery, prompt: Text(appLanguage == "tr" ? "Ne üzerinde çalışacaksın?" : "What will you work on?").foregroundStyle(Color(white: 0.35)))
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .focused($isSearchFocused)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Work Item Row

    private func goalStatusText(for name: String) -> String {
        let activeGoals = WorkGoalStore.shared.goals.filter {
            $0.scope == .workArea && $0.isEnabled && $0.workAreaName?.localizedCaseInsensitiveCompare(name) == .orderedSame
        }

        if let goal = activeGoals.first(where: { $0.period == .weekly }) ?? activeGoals.first(where: { $0.period == .daily }) ?? activeGoals.first {
            let periodTitle = goal.period.title(lang: appLanguage)
            let hrs = Double(goal.targetSeconds) / 3600.0
            let formattedTime: String
            if hrs == floor(hrs) {
                formattedTime = "\(Int(hrs)) " + (appLanguage == "tr" ? "sa" : "h")
            } else {
                formattedTime = String(format: "%.1f ", hrs) + (appLanguage == "tr" ? "sa" : "h")
            }
            return appLanguage == "tr" ? "\(periodTitle) hedef: \(formattedTime)" : "\(periodTitle) goal: \(formattedTime)"
        } else {
            return appLanguage == "tr" ? "Hedef yok" : "No goal"
        }
    }

    private func workItemRow(subject: Subject, action: @escaping () -> Void) -> some View {
        let isSelected = selectedWorkItem?.localizedCaseInsensitiveCompare(subject.name) == .orderedSame
        let activeSubjects = savedSubjects.filter { !$0.isArchived }
        let isLocked = WorkItemLimits.isSubjectLocked(subject, allSubjects: activeSubjects, isPremiumUser: isPremiumUser)
        let goalText = goalStatusText(for: subject.name)

        return Button {
            if isLocked {
                HapticService.warning()
                showPaywallSheet = true
            } else {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isLocked ? "lock.fill" : "square.and.pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35) : (isSelected ? Color.black : Color(white: 0.5)))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(subject.name)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(isLocked ? Color(white: 0.65) : (isSelected ? Color.black : Color(white: 0.9)))
                            .lineLimit(1)

                        if isLocked {
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(red: 0.95, green: 0.78, blue: 0.35)))
                        }
                    }

                    if isLocked {
                        Text(appLanguage == "tr" ? "PRO ile tekrar aktif olur" : "Unlocks with PRO")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))
                            .lineLimit(1)
                    } else {
                        Text(goalText)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.65) : Color(white: 0.45))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white : Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.white : Color(white: 0.14), lineWidth: 0.5)
                    )
            )
            .opacity(isLocked ? 0.75 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State Info

    private var emptyStateInfo: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color(white: 0.40))
                .padding(.top, 16)

            VStack(alignment: .center, spacing: 4) {
                Text(appLanguage == "tr" ? "Henüz çalışma eklemedin." : "No work areas added yet.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.90))
                    .multilineTextAlignment(.center)

                Text(appLanguage == "tr" ? "Odak oturumunu etiketlemek için önce bir çalışma oluştur." : "To tag your focus session, create a work area first.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
                    .multilineTextAlignment(.center)
            }

            Button {
                showWorkItemManagementSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text(appLanguage == "tr" ? "Çalışmalarım'a Git" : "Go to My Work Areas")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func selectExistingSubject(_ subject: Subject) {
        let normalized = subject.name.normalizedWorkItemName()
        subject.name = normalized.isEmpty ? subject.name : normalized
        subject.lastUsedDate = Date()
        subject.updatedAt = Date()
        try? modelContext.save()
        SyncService.shared.syncSubject(subject)
        selectedWorkItem = subject.name
        dismiss()
    }

    private func performRename() {
        guard let subject = subjectToRename else { return }
        let oldName = subject.name
        let newName = renameText.normalizedWorkItemName()

        guard !newName.isEmpty && newName != oldName else {
            subjectToRename = nil
            renameText = ""
            return
        }

        // Update Subject model entity
        subject.name = newName
        subject.updatedAt = Date()
        subject.lastUsedDate = Date()

        // Update matching past FocusSessions so historical reports update to the new name
        for session in allSessions {
            if let subj = session.subject, subj.localizedCaseInsensitiveCompare(oldName) == .orderedSame {
                session.subject = newName
            }
        }

        if selectedWorkItem?.localizedCaseInsensitiveCompare(oldName) == .orderedSame {
            selectedWorkItem = newName
        }

        do {
            try modelContext.save()
            SyncService.shared.syncSubject(subject)
            allSessions
                .filter { $0.subject?.localizedCaseInsensitiveCompare(newName) == .orderedSame }
                .forEach { SyncService.shared.syncSession($0) }
        } catch {
            HapticService.error()
        }
        subjectToRename = nil
        renameText = ""
    }

    private func performDelete(_ subject: Subject) {
        let name = subject.name

        subject.archivedAt = Date()
        subject.updatedAt = Date()

        if selectedWorkItem?.localizedCaseInsensitiveCompare(name) == .orderedSame {
            selectedWorkItem = nil
        }

        do {
            try modelContext.save()
            SyncService.shared.syncSubject(subject)
        } catch {
            HapticService.error()
        }
        subjectToDelete = nil
    }
}
