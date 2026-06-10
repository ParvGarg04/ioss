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

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeroCard
                    statsCard
                    rewardsLinkCard
                    preferencesCard
                    reminderInfoCard
                    accountCard
                    appFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
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
                Text("Please enable notifications in Settings to receive reminders.")
            }
        }
    }

    // MARK: - Hero Card
    private var profileHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.gradient)
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 16, y: 8)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 80, height: 80)
                    Text(initials)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text(authViewModel.currentUser?.name ?? "Member")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(authViewModel.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                HStack(spacing: 20) {
                    heroPill(icon: "heart.fill", value: "\(authViewModel.currentUser?.streak ?? 0)", label: "Day Streak")
                    Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 32)
                    heroPill(icon: "star.fill", value: "\(authViewModel.currentUser?.pointBalance ?? 0)", label: "Points")
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 28)
        }
    }

    private func heroPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: - Stats Card
    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(authViewModel.currentUser?.streak ?? 0)", label: "Streak", icon: "heart.fill", color: AppTheme.accent)
            Divider().frame(height: 40).opacity(0.5)
            statItem(value: "\(authViewModel.currentUser?.pointBalance ?? 0)", label: "Points", icon: "star.fill", color: AppTheme.warning)
            Divider().frame(height: 40).opacity(0.5)
            statItem(value: "Member", label: "Role", icon: "person.fill", color: AppTheme.accent)
        }
        .padding(.vertical, 16)
        .cardStyle()
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textDark)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rewards Link
    private var rewardsLinkCard: some View {
        NavigationLink(destination: RewardsView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "star.fill")
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rewards & Points")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textDark)
                    Text("\(authViewModel.currentUser?.pointBalance ?? 0) points available")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preferences Card
    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preferences")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                prefToggleRow(
                    label: "Notifications",
                    icon: "bell.fill",
                    iconColor: AppTheme.accent,
                    isOn: $notificationsEnabled,
                    tint: AppTheme.accent
                )
                .onChange(of: notificationsEnabled) { _, e in Task { await syncNotifications(enabled: e) } }

                Divider().padding(.leading, 56)

                prefToggleRow(
                    label: "Emergency Silence",
                    icon: "bell.slash.fill",
                    iconColor: AppTheme.warning,
                    isOn: $emergencyMuted,
                    tint: AppTheme.warning
                )
                .onChange(of: emergencyMuted) { _, m in Task { await syncEmergencyMute(muted: m) } }

                Divider().padding(.leading, 56)

                prefToggleRow(
                    label: "Dark Mode",
                    icon: "moon.fill",
                    iconColor: Color.indigo,
                    isOn: $themeManager.isDarkMode,
                    tint: AppTheme.accent
                )
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.softBorder, lineWidth: 1)
            )
        }
    }

    private func prefToggleRow(label: String, icon: String, iconColor: Color, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textDark)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(tint)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Reminder Info
    private var reminderInfoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reminder Schedule")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                reminderRow("Hydration Window",  value: "10:00 AM – 10:00 PM", icon: "drop.fill",           color: AppTheme.accent)
                Divider().padding(.leading, 56)
                reminderRow("Check Interval",    value: "Hourly + follow-ups",  icon: "clock.arrow.2.circlepath", color: AppTheme.lavender)
                Divider().padding(.leading, 56)
                reminderRow("Photo Requirement", value: "3 per day",            icon: "camera.fill",          color: AppTheme.warning)
                Divider().padding(.leading, 56)
                reminderRow("Task Reminders",    value: "Due, +10 min, +30 min",icon: "checklist",            color: AppTheme.success)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.softBorder, lineWidth: 1)
            )
        }
    }

    private func reminderRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textDark)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Account Card
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Account")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                Button {
                    showLogoutConfirm = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(AppTheme.warning.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.warning)
                        }
                        Text("Sign Out")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textDark)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 56)

                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(AppTheme.danger.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.danger)
                        }
                        Text("Delete Account")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.danger)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.softBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Footer
    private var appFooter: some View {
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers
    private var initials: String {
        let name = authViewModel.currentUser?.name ?? "M"
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private func loadPreferences() async {
        let status = await NotificationService.shared.checkPermissionStatus()
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
            if !granted { notificationsEnabled = false; showNotifAlert = true; return }
            await NotificationService.shared.scheduleWaterReminders()
        } else {
            NotificationService.shared.cancelAllNotifications()
        }
        try? await FirestoreService.shared.updateUserProfile(uid: uid, fields: ["notificationsEnabled": enabled])
        await authViewModel.fetchProfile(uid: uid)
    }

    private func syncEmergencyMute(muted: Bool) async {
        guard let uid = authViewModel.currentUser?.id else { return }
        let mutedUntil: Date?
        if muted {
            var end = Calendar.current.startOfDay(for: Date())
            end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? Date()
            mutedUntil = end
            NotificationService.shared.setEmergencyMute(until: end)
        } else {
            mutedUntil = nil
            NotificationService.shared.setEmergencyMute(until: nil)
            await NotificationService.shared.scheduleWaterReminders()
        }
        try? await FirestoreService.shared.updateUserProfile(uid: uid, fields: [
            "emergencyMutedUntil": muted ? Timestamp(date: mutedUntil!) : FieldValue.delete()
        ])
        await authViewModel.fetchProfile(uid: uid)
    }
}
