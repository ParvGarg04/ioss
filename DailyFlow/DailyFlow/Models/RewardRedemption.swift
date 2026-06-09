import Foundation
import FirebaseFirestore

enum RewardTier: Int, Codable, CaseIterable, Identifiable {
    case adminTask  = 1000
    case special    = 2000
    case gift       = 5000

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .adminTask: return "Admin Task Request"
        case .special:   return "Special Reward"
        case .gift:      return "Premium Gift"
        }
    }

    var description: String {
        switch self {
        case .adminTask: return "Send the admin a custom task to complete for you"
        case .special:   return "Request a special treat or privilege"
        case .gift:      return "Redeem a premium gift from the admin"
        }
    }

    var icon: String {
        switch self {
        case .adminTask: return "person.badge.plus"
        case .special:   return "star.fill"
        case .gift:      return "gift.fill"
        }
    }
}

enum RedemptionStatus: String, Codable {
    case pending   = "pending"
    case fulfilled = "fulfilled"
    case rejected  = "rejected"
}

struct RewardRedemption: Identifiable, Codable {
    @DocumentID var id: String?
    var redemptionId: String
    var userId:       String
    var userName:     String
    var tier:         Int
    var message:      String
    var status:       RedemptionStatus
    var requestedAt:  Date
    var fulfilledAt:  Date?
    var adminNote:    String?

    init(
        id: String? = nil,
        redemptionId: String = UUID().uuidString,
        userId: String,
        userName: String,
        tier: Int,
        message: String,
        status: RedemptionStatus = .pending,
        requestedAt: Date = Date(),
        fulfilledAt: Date? = nil,
        adminNote: String? = nil
    ) {
        self.id = id
        self.redemptionId = redemptionId
        self.userId = userId
        self.userName = userName
        self.tier = tier
        self.message = message
        self.status = status
        self.requestedAt = requestedAt
        self.fulfilledAt = fulfilledAt
        self.adminNote = adminNote
    }
}

enum PointsConfig {
    static let waterVerified  = 20
    static let taskVerified   = 50
    static let dailyBonus     = 30
    static let requiredImageLogsPerDay = 3
}
