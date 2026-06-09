import Foundation
import FirebaseFirestore

struct EmergencyAlert: Identifiable, Codable {
    @DocumentID var id: String?
    var alertId:    String
    var title:      String
    var message:    String
    var createdAt:  Date
    var createdBy:  String
    var isActive:   Bool

    init(
        id: String? = nil,
        alertId: String = UUID().uuidString,
        title: String,
        message: String,
        createdAt: Date = Date(),
        createdBy: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.alertId = alertId
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.isActive = isActive
    }
}
