import Foundation

public struct AppMemento: Codable {
    public var startTime: Date?
    public var configuration: IntervalConfiguration
    public var lastStretchTime: Date

    private enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case configuration = "configuration"
        case lastStretchTime = "last_stretch"
    }
    
    public init() {
        self.init(startTime: nil, configuration: .deep.first!, lastStretchTime: .distantPast)
    }
    
    public init(startTime: Date?, configuration: IntervalConfiguration, lastStretchTime: Date) {
        self.startTime = startTime
        self.configuration = configuration
        self.lastStretchTime = lastStretchTime
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decode(Date?.self, forKey: .startTime)
        configuration = try container.decode(IntervalConfiguration.self, forKey: .configuration)
        lastStretchTime = try container.decodeIfPresent(Date.self, forKey: .lastStretchTime) ?? .distantPast
    }
}
