import SwiftUI

struct RewardsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = RewardsViewModel()
    @State private var selectedTier: RewardTier?
    @State private var requestMessage = ""

    private let tiers = RewardTier.allCases

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        pointsHeroCard
                        progressToNextCard
                        howToEarnCard
                        rewardsSection
                        if !viewModel.redemptions.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }

                if viewModel.showToast {
                    ToastBanner(
                        message: viewModel.successMessage ?? viewModel.errorMessage ?? "",
                        isSuccess: viewModel.successMessage != nil
                    )
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Rewards")
            .refreshable { await viewModel.loadData() }
            .task { await viewModel.loadData() }
            .sheet(item: $selectedTier) { tier in
                redeemSheet(for: tier)
            }
        }
    }

    // MARK: - Points Hero
    private var pointsHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.gradient)
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 18, y: 8)

            VStack(spacing: 10) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(viewModel.points)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Wellness Points")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                // Unlocked tier chips inside hero
                HStack(spacing: 8) {
                    ForEach(tiers) { tier in
                        let unlocked = viewModel.points >= tier.rawValue
                        VStack(spacing: 3) {
                            Image(systemName: tier.icon)
                                .font(.system(size: 12))
                            Text(tier.rawValue < 1000 ? "\(tier.rawValue)" : "\(tier.rawValue/1000)k")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(unlocked ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(unlocked ? 0.2 : 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
    }

    // MARK: - Progress to Next Reward
    private var progressToNextCard: some View {
        let pts = viewModel.points
        guard let next = tiers.first(where: { pts < $0.rawValue }) else {
            return AnyView(
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All rewards unlocked!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textDark)
                        Text("You've reached every tier 🎉")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                .cardStyle()
            )
        }

        let prev = tiers.last(where: { pts >= $0.rawValue })?.rawValue ?? 0
        let progress = Double(pts - prev) / Double(next.rawValue - prev)
        let needed = next.rawValue - pts

        return AnyView(
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next: \(next.title)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textDark)
                        Text("\(needed) more pts needed")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: next.icon)
                        .font(.title2)
                        .foregroundStyle(AppTheme.accent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.softBorder.opacity(0.5))
                            .frame(height: 12)
                        Capsule()
                            .fill(AppTheme.gradient)
                            .frame(width: max(12, geo.size.width * progress), height: 12)
                            .animation(.easeInOut(duration: 0.9), value: progress)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(prev) pts")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Text("\(next.rawValue) pts")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .cardStyle()
        )
    }

    // MARK: - How to Earn
    private var howToEarnCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How to Earn", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textDark)

            VStack(spacing: 8) {
                earnRow("Verified hydration log", value: "+\(PointsConfig.waterVerified) pts", icon: "drop.fill", color: AppTheme.accent)
                earnRow("Verified task completion", value: "+\(PointsConfig.taskVerified) pts", icon: "checkmark.circle.fill", color: AppTheme.success)
                earnRow("Daily routine bonus", value: "+\(PointsConfig.dailyBonus) pts", icon: "star.fill", color: AppTheme.warning)
            }

            Text("Complete your full daily routine and get admin verification to earn points.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func earnRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textDark)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.accent)
        }
    }

    // MARK: - Rewards Section
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Redeem Rewards")
                .font(.headline)
                .foregroundStyle(AppTheme.textDark)

            ForEach(tiers) { tier in
                rewardCard(tier)
            }
        }
    }

    private func rewardCard(_ tier: RewardTier) -> some View {
        let canRedeem = viewModel.points >= tier.rawValue
        let progress = min(Double(viewModel.points) / Double(tier.rawValue), 1.0)

        return Button {
            selectedTier = tier
            requestMessage = ""
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: tier.icon)
                        .font(.title2)
                        .foregroundStyle(canRedeem ? AppTheme.accent : AppTheme.secondaryText)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.lavender.opacity(canRedeem ? 0.22 : 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tier.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textDark)
                        Text(tier.description)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(tier.rawValue)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(canRedeem ? .white : AppTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(canRedeem ? AnyShapeStyle(AppTheme.gradient) : AnyShapeStyle(AppTheme.softBorder.opacity(0.5)))
                            .clipShape(Capsule())
                        if canRedeem {
                            Text("Available")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }
                .padding(16)

                // Mini progress bar inside card
                if !canRedeem {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.softBorder.opacity(0.4))
                                .frame(height: 3)
                            Rectangle()
                                .fill(AppTheme.gradient)
                                .frame(width: geo.size.width * progress, height: 3)
                                .animation(.easeInOut(duration: 0.7), value: progress)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(canRedeem ? AppTheme.accent.opacity(0.3) : AppTheme.softBorder, lineWidth: canRedeem ? 1.5 : 1)
            )
            .shadow(color: canRedeem ? AppTheme.accent.opacity(0.15) : AppTheme.cardShadow, radius: canRedeem ? 12 : 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!canRedeem)
        .opacity(canRedeem ? 1 : 0.7)
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Requests")
                .font(.headline)
                .foregroundStyle(AppTheme.textDark)

            ForEach(viewModel.redemptions.prefix(10)) { item in
                HStack(spacing: 14) {
                    Image(systemName: RewardTier(rawValue: item.tier)?.icon ?? "gift")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(RewardTier(rawValue: item.tier)?.title ?? "\(item.tier) pts")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textDark)
                        Text(item.message)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                    StatusBadge(status: item.status == .fulfilled ? .verified : (item.status == .rejected ? .rejected : .pendingReview))
                }
                .padding(14)
                .cardStyle()
            }
        }
    }

    // MARK: - Redeem Sheet
    private func redeemSheet(for tier: RewardTier) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: tier.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text(tier.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textDark)
                    Text("Costs \(tier.rawValue) points · You have \(viewModel.points)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Request")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    TextField(tier == .adminTask ? "What should the admin do?" : "Describe your reward request", text: $requestMessage, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(DailyFlowTextFieldStyle())
                }

                Button {
                    Task {
                        let name = authViewModel.currentUser?.name ?? "Member"
                        let ok = await viewModel.redeem(tier: tier, message: requestMessage, userName: name)
                        if ok { selectedTier = nil }
                    }
                } label: {
                    Text("Redeem \(tier.rawValue) Points")
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: viewModel.isRedeeming))
                .disabled(viewModel.isRedeeming || requestMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Redeem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selectedTier = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension RewardTier: Hashable {}
