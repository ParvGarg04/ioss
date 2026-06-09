import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authViewModel:  AuthViewModel
    @EnvironmentObject var themeManager:   ThemeManager
    @State private var notificationsEnabled = true
    @State private var emergencyMuted = false
    @State private var showDeleteConfirm    = false
    @State private var showLogoutConfirm    = false
    @State private var showNotifAlert       = false
    @State private var showEmergencyConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section { profileHeader }

                Section { statsSummaryRow }

                Section {
                    NavigationLink(destination: RewardsView()) {
                        Label("Rewards & Points", systemImage: "star.fill")
                    }
                }

                Section("Preferences") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    .tint(AppTheme.accent)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        Task {
                            await syncNotifications(enabled: enabled)
                        }
                    }

                    Toggle(isOn: $emergencyMuted) {
                        Label("Emergency Silence", systemImage: "bell.slash.fill")
                    }
                    .tint(AppTheme.warning)
                    .onChange(of: emergencyMuted) { _, muted in
                        Task { await syncEmergencyMute(muted: muted) }
                    }

                    Toggle(isOn: $themeManager.isDarkMode) {
                        Label("Dark Mode", systemImage: "moon.fill")
                    }
                    .tint(AppTheme.accent)
                }

                Section("Reminder Schedule") {
                    reminderInfoRow("Hydration Window", value: "10:00 AM – 10:00 PM", icon: "drop.fill")
                    reminderInfoRow("Check Interval", value: "Every hour (+10 & +30 min)", icon: "clock.arrow.2.circlepath")
                    reminderInfoRow("Photo Requirement", value: "3 per day", icon: "camera.fill")
                    reminderInfoRow("Task Reminders", value: "At due time, +10 min, +30 min", icon: "checklist")
                }

                Section("Account") {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "trash.fill")
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.lavender.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            Text("DailyFlow")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textDark)
                            Text("Wellness & Routine Tracker")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("Version 1.0.0")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .task { await loadPreferences() }
            .confirmationDialog("Sign out of DailyFlow?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authViewModel.signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete your account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task { await authViewModel.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Enable Notifications", isPresented: $showNotifAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive hydration and task reminders.")
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.gradient)
                    .frame(width: 62, height: 62)
                Text(initials)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(authViewModel.currentUser?.name ?? "Member")
                    .font(.headline)
                Text(authViewModel.currentUser?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        Text("\(authViewModel.currentUser?.streak ?? 0) day streak")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        Text("\(authViewModel.currentUser?.pointBalance ?? 0) pts")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Stats Summary
    private var statsSummaryRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(authViewModel.currentUser?.streak ?? 0)", label: "Day Streak", icon: "heart.fill", color: AppTheme.accent)
            Divider().frame(height: 40)
            statItem(value: "\(authViewModel.currentUser?.pointBalance ?? 0)", label: "Points", icon: "star.fill", color: AppTheme.warning)
            Divider().frame(height: 40)
            statItem(value: "Member", label: "Role", icon: "person.fill", color: AppTheme.accent)
        }
        .padding(.vertical, 8)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func reminderInfoRow(_ title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var initials: String {
        let name = authViewModel.currentUser?.name ?? "M"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func loadPreferences() async {
        let status = await NotificationService.shared.checkPermissionStatus()
        notificationsEnabled = status == .authorized

        if let profile = authViewModel.currentUser {
            notificationsEnabled = profile.isNotificationsOn && status == .authorized
            if let mutedUntil = profile.emergencyMutedUntil {
                emergencyMuted = mutedUntil > Date()
                NotificationService.shared.setEmergencyMute(until: mutedUntil)
            }
        }
    }

    private func syncNotifications(enabled: Bool) async {
        guard let uid = authViewModel.currentUser?.id else { return }

        if enabled {
            let granted = await NotificationService.shared.requestPermission()
            if !granted {
                notificationsEnabled = false
                showNotifAlert = true
                return
            }
            await NotificationService.shared.scheduleWaterReminders()
        } else {
            NotificationService.shared.cancelAllNotifications()
        }

        try? await FirestoreService.shared.updateUserProfile(uid: uid, fields: [
            "notificationsEnabled": enabled
        ])
        await authViewModel.fetchProfile(uid: uid)
    }

    private func syncEmergencyMute(muted: Bool) async {
        guard let uid = authViewModel.currentUser?.id else { return }

        let mutedUntil: Date?
        if muted {
            let cal = Calendar.current
            var endOfDay = cal.startOfDay(for: Date())
            endOfDay = cal.date(byAdding: .day, value: 1, to: endOfDay) ?? Date()
            mutedUntil = endOfDay
            NotificationService.shared.setEmergencyMute(until: endOfDay)
        } else {
            mutedUntil = nil
            NotificationService.shared.setEmergencyMute(until: nil)
            await NotificationService.shared.scheduleWaterReminders()
        }

        try? await FirestoreService.shared.updateUserProfile(uid: uid, fields: [
            "emergencyMutedUntil": muted
                ? Timestamp(date: mutedUntil!)
                : FieldValue.delete()
        ])
        await authViewModel.fetchProfile(uid: uid)
    }
}
