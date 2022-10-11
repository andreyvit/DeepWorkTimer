import Foundation

public struct AppMemento: Codable {
    public var startTime: Date?
    public var configuration: IntervalConfiguration
    public var lastStretchTime: Date
    public var totalMuting: Muting? = nil
    public var stretchMuting: Muting? = nil

    private enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case configuration = "configuration"
        case lastStretchTime = "last_stretch"
        case totalMuting = "muting_total"
        case stretchMuting = "muting_stretch"
    }
    
    public init() {
        self.init(startTime: nil, configuration: .deep.first!, lastStretchTime: .distantPast, totalMuting: nil, stretchMuting: nil)
    }
    
    public init(startTime: Date?, configuration: IntervalConfiguration, lastStretchTime: Date, totalMuting: Muting?, stretchMuting: Muting?) {
        self.startTime = startTime
        self.configuration = configuration
        self.lastStretchTime = lastStretchTime
        self.totalMuting = totalMuting
        self.stretchMuting = stretchMuting
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decode(Date?.self, forKey: .startTime)
        configuration = try container.decode(IntervalConfiguration.self, forKey: .configuration)
        lastStretchTime = try container.decodeIfPresent(Date.self, forKey: .lastStretchTime) ?? .distantPast
        totalMuting = try container.decodeIfPresent(Muting?.self, forKey: .totalMuting) ?? nil
        stretchMuting = try container.decodeIfPresent(Muting?.self, forKey: .stretchMuting) ?? nil
    }
}
