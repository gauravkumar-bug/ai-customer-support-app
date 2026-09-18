import Foundation

// MARK: - Order Model

struct Order: Codable, Identifiable, Sendable {
    let orderId: String
    let customerId: String
    let customerName: String
    let phone: String
    let email: String
    let address: String
    let product: String
    let status: String
    let deliveryDate: String
    let price: Double
    let createdAt: String
    let updatedAt: String

    var id: String {
        orderId
    }

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case phone
        case email
        case address
        case product
        case status
        case deliveryDate = "delivery_date"
        case price
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Default Memberwise Initializer
    init(
        orderId: String,
        customerId: String = "",
        customerName: String = "",
        phone: String = "",
        email: String = "",
        address: String = "",
        product: String = "",
        status: String = "",
        deliveryDate: String = "",
        price: Double = 0.0,
        createdAt: String = "",
        updatedAt: String = ""
    ) {
        self.orderId = orderId
        self.customerId = customerId
        self.customerName = customerName
        self.phone = phone
        self.email = email
        self.address = address
        self.product = product
        self.status = status
        self.deliveryDate = deliveryDate
        self.price = price
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Decoder Initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try container.decodeIfPresent(String.self, forKey: .orderId) ?? ""
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId) ?? ""
        customerName = try container.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        product = try container.decodeIfPresent(String.self, forKey: .product) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        deliveryDate = try container.decodeIfPresent(String.self, forKey: .deliveryDate) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""

        // Price handling for both Int and Double safely
        if let priceDouble = try? container.decodeIfPresent(Double.self, forKey: .price) {
            price = priceDouble
        } else if let priceInt = try? container.decodeIfPresent(Int.self, forKey: .price) {
            price = Double(priceInt)
        } else {
            price = 0.0
        }
    }
}
