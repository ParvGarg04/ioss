import Foundation
import SwiftUI

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var points: Int = 0
    @Published var redemptions: [RewardRedemption] = []
    @Published var isLoading = false
    @Published var isRedeeming = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showToast = false

    private let firestore = FirestoreService.shared
    private let auth = AuthService.shared

    func loadData() async {
        guard let userId = auth.currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let profile = firestore.fetchUser(uid: userId)
            async let history = firestore.fetchRedemptions(for: userId)
            let (user, redemptions) = try await (profile, history)
            points = user?.pointBalance ?? 0
            self.redemptions = redemptions
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func redeem(tier: RewardTier, message: String, userName: String) async -> Bool {
        guard let userId = auth.currentUser?.uid else { return false }
        guard points >= tier.rawValue else {
            showError("You need \(tier.rawValue) points. You have \(points).")
            return false
        }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Please describe your request.")
            return false
        }

        isRedeeming = true
        defer { isRedeeming = false }

        do {
            try await firestore.redeemReward(
                userId: userId,
                userName: userName,
                tier: tier,
                message: message,
                currentPoints: points
            )
            await loadData()
            showSuccess("Reward requested! Admin will review it.")
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    private func showSuccess(_ msg: String) {
        successMessage = msg
        errorMessage = nil
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.showToast = false }
        }
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        successMessage = nil
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.showToast = false }
        }
    }
}
