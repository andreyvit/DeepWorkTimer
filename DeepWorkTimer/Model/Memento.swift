import Foundation

struct AppMemento: Codable {
    var startTime: Date?
    var configuration: IntervalConfiguration
    var lastStretchTime: Date

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case configuration = "configuration"
        case lastStretchTime = "last_stretch"
    }
    
    init(startTime: Date?, configuration: IntervalConfiguration, lastStretchTime: Date) {
        self.startTime = startTime
        self.configuration = configuration
        self.lastStretchTime = lastStretchTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decode(Date?.self, forKey: .startTime)
        configuration = try container.decode(IntervalConfiguration.self, forKey: .configuration)
        lastStretchTime = try container.decodeIfPresent(Date.self, forKey: .lastStretchTime) ?? .distantPast
    }
}
