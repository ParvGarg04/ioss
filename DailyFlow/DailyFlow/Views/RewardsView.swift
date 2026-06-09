import SwiftUI

struct RewardsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = RewardsViewModel()
    @State private var selectedTier: RewardTier?
    @State private var requestMessage = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        pointsCard
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

    private var pointsCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.accent)
            Text("\(viewModel.points)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textDark)
            Text("Wellness Points")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .cardStyle(elevated: true)
    }

    private var howToEarnCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to Earn")
                .font(.headline)
            earnRow("Verified hydration log", "+\(PointsConfig.waterVerified) pts")
            earnRow("Verified task completion", "+\(PointsConfig.taskVerified) pts")
            earnRow("Daily routine bonus", "+\(PointsConfig.dailyBonus) pts")
            Text("Follow your full daily routine and get admin verification to earn points.")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    private func earnRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
    }

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Redeem Rewards")
                .font(.headline)

            ForEach(RewardTier.allCases) { tier in
                rewardCard(tier)
            }
        }
    }

    private func rewardCard(_ tier: RewardTier) -> some View {
        let canRedeem = viewModel.points >= tier.rawValue
        return Button {
            selectedTier = tier
            requestMessage = ""
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tier.icon)
                    .font(.title2)
                    .foregroundStyle(canRedeem ? AppTheme.accent : AppTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.lavender.opacity(canRedeem ? 0.2 : 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                Text("\(tier.rawValue)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(canRedeem ? .white : AppTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(canRedeem ? AnyShapeStyle(AppTheme.gradient) : AnyShapeStyle(AppTheme.softBorder.opacity(0.5)))
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.softBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canRedeem)
        .opacity(canRedeem ? 1 : 0.65)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Requests")
                .font(.headline)
            ForEach(viewModel.redemptions.prefix(10)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(RewardTier(rawValue: item.tier)?.title ?? "\(item.tier) pts")
                            .font(.subheadline.weight(.medium))
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

    private func redeemSheet(for tier: RewardTier) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: tier.icon)
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.accent)
                    Text(tier.title)
                        .font(.title3.weight(.bold))
                    Text("Costs \(tier.rawValue) points")
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
