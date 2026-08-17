//
//  WorkItemManagementView.swift
//  Yonder
//

import SwiftUI
import SwiftData

/// View for managing saved work items (renaming and deleting) in Settings.
struct WorkItemManagementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @AppStorage("app_language") private var appLanguage: String = "en"

    private var isIPad: Bool { hSizeClass == .regular }

    @Query(sort: \Subject.name) private var savedSubjects: [Subject]
    @Query private var allSessions: [FocusSession]

    @State private var subjectToRename: Subject? = nil
    @State private var renameText: String = ""
    @State private var showRenameAlert: Bool = false

    @State private var subjectToDelete: Subject? = nil
    @State private var showDeleteConfirmation: Bool = false

    @AppStorage("is_premium_user") private var isPremiumUser: Bool = false

    @State private var newSubjectText: String = ""
    @State private var searchQuery: String = ""
    @State private var addErrorText: String? = nil
    @State private var showPaywallSheet: Bool = false

    private var filteredSubjects: [Subject] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeSubjects = savedSubjects.filter { !$0.isArchived }
        if trimmed.isEmpty {
            return activeSubjects
        } else {
            return activeSubjects.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    private var activeSubjects: [Subject] {
        savedSubjects.filter { !$0.isArchived }
    }

    private var archivedSubjects: [Subject] {
        savedSubjects.filter { $0.isArchived }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────────
                headerView

                // ── Add New Work Area Input Card ─────────────────────────
                addSubjectSection
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .padding(.horizontal, isIPad ? 60 : 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if !activeSubjects.isEmpty {
                    // Search Field
                    searchBar
                        .frame(maxWidth: isIPad ? 680 : .infinity)
                        .padding(.horizontal, isIPad ? 60 : 20)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                }

                // ── List of Work Areas ───────────────────────────────────
                if activeSubjects.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if filteredSubjects.isEmpty {
                                noResultsInlineView
                            } else {
                                Text(appLanguage == "tr" ? "ÇALIŞMALAR" : "WORK AREAS")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(Color(white: 0.4))
                                    .tracking(2)
                                    .padding(.leading, 4)
                                    .padding(.top, 4)

                                VStack(spacing: 8) {
                                    ForEach(filteredSubjects) { subject in
                                        workItemManagementRow(subject)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: isIPad ? 680 : .infinity)
                        .padding(.horizontal, isIPad ? 60 : 20)
                        .padding(.bottom, 24)
                    }
                }
            }
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
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywallSheet) {
            YonderPaywallSheetView {
                isPremiumUser = true
                showPaywallSheet = false
            }
        }
        .onAppear {
            WorkItemMaintenanceHelper.cleanAndNormalizeSubjects(
                modelContext: modelContext,
                savedSubjects: savedSubjects,
                allSessions: allSessions
            )
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text(appLanguage == "tr" ? "Ayarlar" : "Settings")
                        .font(.system(size: 14, design: .rounded))
                }
                .foregroundStyle(Color(white: 0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(appLanguage == "tr" ? "Çalışmalarım" : "My Work Areas")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.9))

            Spacer()

            // Balance header width
            Color.clear
                .frame(width: 70, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var addSubjectSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.8))

                TextField("", text: $newSubjectText, prompt: Text(appLanguage == "tr" ? "Yeni çalışma adı (örn. Matematik)" : "New work area name (e.g. Math)").foregroundStyle(Color(white: 0.35)))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white)
                    .onSubmit {
                        addNewSubject()
                    }

                Button {
                    addNewSubject()
                } label: {
                    Text(appLanguage == "tr" ? "Ekle" : "Add")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(newSubjectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(white: 0.4) : Color.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(newSubjectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(white: 0.12) : Color.white)
                        )
                }
                .buttonStyle(.plain)
                .disabled(newSubjectText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                    )
            )

            if WorkItemLimits.isLimitReached(currentCount: activeSubjects.count, isPremiumUser: isPremiumUser) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.95, green: 0.78, blue: 0.35))

                    Text(appLanguage == "tr"
                         ? "Ücretsiz planda en fazla 10 çalışma ekleyebilirsin. Daha fazlası için Yonder PRO."
                         : "The free plan supports up to 10 work areas. Unlock Yonder PRO for more.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color(white: 0.85))
                        .lineLimit(2)

                    Spacer()

                    Text("PRO")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(red: 0.95, green: 0.78, blue: 0.35)))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.35), lineWidth: 0.5)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showPaywallSheet = true
                }
            }

            if let err = addErrorText {
                Text(err)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.55))
                    .padding(.leading, 4)
            }
        }
    }

    private func addNewSubject() {
        let normalized = newSubjectText.normalizedWorkItemName()
        guard !normalized.isEmpty else { return }

        if let archived = archivedSubjects.first(where: { $0.name.normalizedWorkItemName().localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            restoreSubject(archived)
            newSubjectText = ""
            searchQuery = ""
            addErrorText = nil
            return
        }

        if WorkItemLimits.isLimitReached(currentCount: activeSubjects.count, isPremiumUser: isPremiumUser) {
            addErrorText = appLanguage == "tr"
                ? "Ücretsiz planda en fazla 10 çalışma ekleyebilirsin. Daha fazlası için Yonder PRO."
                : "The free plan supports up to 10 work areas. Unlock Yonder PRO for more."
            showPaywallSheet = true
            HapticService.warning()
            return
        }

        if activeSubjects.contains(where: { $0.name.normalizedWorkItemName().localizedCaseInsensitiveCompare(normalized) == .orderedSame }) {
            addErrorText = appLanguage == "tr" ? "Bu çalışma zaten mevcut." : "This work area already exists."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { addErrorText = nil }
            return
        }

        let subject = Subject(name: normalized, lastUsedDate: Date())
        modelContext.insert(subject)
        do {
            try modelContext.save()
            SyncService.shared.syncSubject(subject)
            newSubjectText = ""
            searchQuery = ""
            addErrorText = nil
            HapticService.success()
        } catch {
            modelContext.delete(subject)
            addErrorText = appLanguage == "tr"
                ? "Çalışma eklenemedi. Lütfen tekrar dene."
                : "Could not add work area. Please try again."
            HapticService.error()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.45))

            TextField("", text: $searchQuery, prompt: Text(appLanguage == "tr" ? "Çalışmalarda ara..." : "Search work areas...").foregroundStyle(Color(white: 0.35)))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(white: 0.16), lineWidth: 0.5)
                )
        )
    }

    private func statsForSubject(_ name: String) -> (totalSeconds: Int, count: Int) {
        let sessions = allSessions.filter { ($0.subject ?? "").localizedCaseInsensitiveCompare(name) == .orderedSame }
        let total = sessions.reduce(0) { $0 + $1.durationSeconds }
        return (total, sessions.count)
    }

    private func formattedStats(for subject: Subject) -> String {
        let (totalSecs, count) = statsForSubject(subject.name)
        if count == 0 {
            return appLanguage == "tr" ? "Henüz oturum yok" : "No sessions yet"
        }

        let hrs = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60

        let timeStr: String
        if appLanguage == "tr" {
            timeStr = hrs > 0 ? "\(hrs) sa \(mins) dk" : "\(mins) dk"
            return "\(count) oturum · \(timeStr)"
        } else {
            timeStr = hrs > 0 ? "\(hrs)h \(mins)m" : "\(mins)m"
            return "\(count) \(count == 1 ? "session" : "sessions") · \(timeStr)"
        }
    }

    private func workItemManagementRow(_ subject: Subject) -> some View {
        let isLocked = WorkItemLimits.isSubjectLocked(subject, allSubjects: activeSubjects, isPremiumUser: isPremiumUser)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35).opacity(0.15) : Color(white: 0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: isLocked ? "lock.fill" : "square.and.pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isLocked ? Color(red: 0.95, green: 0.78, blue: 0.35) : Color(white: 0.6))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subject.name)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(isLocked ? Color(white: 0.85) : .white)
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
                } else {
                    Text(formattedStats(for: subject))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color(white: 0.45))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    subjectToRename = subject
                    renameText = subject.name
                    showRenameAlert = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.7))
                        .frame(width: 32, height: 32)
                        .background(Color(white: 0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    subjectToDelete = subject
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                        .frame(width: 32, height: 32)
                        .background(Color(white: 0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.15), lineWidth: 0.5)
                )
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.and.pencil")
                .font(.system(size: 36))
                .foregroundStyle(Color(white: 0.3))

            Text(appLanguage == "tr" ? "Henüz çalışma alanı yok" : "No work areas yet")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.6))

            Text(appLanguage == "tr" ? "İlk oturumundan sonra çalışma alanların burada görünmeye başlayacak." : "Your work areas will start appearing here after your first session.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(appLanguage == "tr" ? "Eşleşen çalışma alanı bulunamadı" : "No matching work areas found")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.5))
            Spacer()
        }
    }

    private var noResultsInlineView: some View {
        Text(appLanguage == "tr" ? "Eşleşen aktif çalışma bulunamadı" : "No matching active work areas")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Color(white: 0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }

    // MARK: - Actions

    private func performRename() {
        guard let subject = subjectToRename else { return }
        let oldName = subject.name
        let newName = renameText.normalizedWorkItemName()

        guard !newName.isEmpty && newName != oldName else {
            subjectToRename = nil
            renameText = ""
            return
        }

        // 1. Update Subject model
        subject.name = newName
        subject.updatedAt = Date()
        subject.lastUsedDate = Date()

        // 2. Update matching past FocusSessions so historical reporting stays consistent
        for session in allSessions {
            if let subj = session.subject, subj.localizedCaseInsensitiveCompare(oldName) == .orderedSame {
                session.subject = newName
            }
        }

        do {
            try modelContext.save()
            SyncService.shared.syncSubject(subject)
            allSessions
                .filter { $0.subject?.localizedCaseInsensitiveCompare(newName) == .orderedSame }
                .forEach { SyncService.shared.syncSession($0) }
        } catch {
            addErrorText = appLanguage == "tr"
                ? "Çalışma güncellenemedi. Lütfen tekrar dene."
                : "Could not update work area. Please try again."
            HapticService.error()
        }
        subjectToRename = nil
        renameText = ""
    }

    private func performDelete(_ subject: Subject) {
        subject.archivedAt = Date()
        subject.updatedAt = Date()
        do {
            try modelContext.save()
            SyncService.shared.syncSubject(subject)
            HapticService.success()
        } catch {
            addErrorText = appLanguage == "tr"
                ? "Çalışma silinemedi. Lütfen tekrar dene."
                : "Could not delete work area. Please try again."
            HapticService.error()
        }
        subjectToDelete = nil
    }

    private func restoreSubject(_ subject: Subject) {
        subject.archivedAt = nil
        subject.updatedAt = Date()
        subject.lastUsedDate = Date()
        do {
            try modelContext.save()
            SyncService.shared.syncSubject(subject)
            HapticService.success()
        } catch {
            addErrorText = appLanguage == "tr"
                ? "Çalışma geri alınamadı. Lütfen tekrar dene."
                : "Could not restore work area. Please try again."
            HapticService.error()
        }
    }
}
