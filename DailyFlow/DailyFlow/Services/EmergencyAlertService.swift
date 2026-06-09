import Foundation
import UserNotifications
import FirebaseFirestore

@MainActor
final class EmergencyAlertService: ObservableObject {
    static let shared = EmergencyAlertService()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var isListening = false
    private var skipInitialSnapshot = true

    private init() {}

    func startListening(userId: String, lastSeenAlertId: String?) {
        guard !isListening else { return }
        isListening = true
        skipInitialSnapshot = true

        listener = db.collection("emergencyAlerts")
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, error == nil, let snapshot else { return }

                if self.skipInitialSnapshot {
                    self.skipInitialSnapshot = false
                    return
                }

                Task { @MainActor in
                    for change in snapshot.documentChanges where change.type == .added {
                        guard let alert = try? change.document.data(as: EmergencyAlert.self) else { continue }
                        await self.processNewAlert(alert, userId: userId, lastSeenAlertId: lastSeenAlertId)
                    }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isListening = false
        skipInitialSnapshot = true
    }

    private func processNewAlert(_ alert: EmergencyAlert, userId: String, lastSeenAlertId: String?) async {
        guard let profile = try? await FirestoreService.shared.fetchUser(uid: userId) else { return }

        if let mutedUntil = profile.emergencyMutedUntil, mutedUntil > Date() { return }
        if !profile.isNotificationsOn { return }

        let lastSeen = profile.lastSeenAlertId ?? lastSeenAlertId ?? ""
        guard alert.alertId != lastSeen else { return }

        await deliverAlert(alert)
        try? await FirestoreService.shared.updateLastSeenAlert(alertId: alert.alertId, for: userId)
    }

    private func deliverAlert(_ alert: EmergencyAlert) async {
        let content = UNMutableNotificationContent()
        content.title = "🚨 \(alert.title)"
        content.body  = alert.message
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = NotificationService.emergencyCategoryId

        let request = UNNotificationRequest(
            identifier: "emergency-\(alert.alertId)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
