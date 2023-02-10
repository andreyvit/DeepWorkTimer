import Foundation

public struct AppMemento: Codable {
    public var running: RunningMemento?
    public var configuration: IntervalConfiguration
    public var lastStretchTime: Date
    public var totalMuting: Muting? = nil
    public var stretchMuting: Muting? = nil
    var interruption: InterruptionMemento? = nil

    private enum CodingKeys: String, CodingKey {
        case running = "running"
        case startTime = "start_time"
        case configuration = "configuration"
        case lastStretchTime = "last_stretch"
        case totalMuting = "muting_total"
        case stretchMuting = "muting_stretch"
        case interruption = "interruption"
    }
    
    public init() {
        self.init(running: nil, configuration: .deep.first!, lastStretchTime: .distantPast, totalMuting: nil, stretchMuting: nil, interruption: nil)
    }
    
    init(running: RunningMemento?, configuration: IntervalConfiguration, lastStretchTime: Date, totalMuting: Muting?, stretchMuting: Muting?, interruption: InterruptionMemento?) {
        self.running = running
        self.configuration = configuration
        self.lastStretchTime = lastStretchTime
        self.totalMuting = totalMuting
        self.stretchMuting = stretchMuting
        self.interruption = interruption
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let memento = try container.decodeIfPresent(RunningMemento?.self, forKey: .running) ?? nil {
            running = memento
        } else if let startTime = try container.decodeIfPresent(Date?.self, forKey: .startTime) ?? nil {
            running = RunningMemento(startTime: startTime, excluded: 0)
        } else {
            running = nil
        }
        configuration = try container.decode(IntervalConfiguration.self, forKey: .configuration)
        lastStretchTime = try container.decodeIfPresent(Date.self, forKey: .lastStretchTime) ?? .distantPast
        totalMuting = try container.decodeIfPresent(Muting?.self, forKey: .totalMuting) ?? nil
        stretchMuting = try container.decodeIfPresent(Muting?.self, forKey: .stretchMuting) ?? nil
        interruption = try container.decodeIfPresent(InterruptionMemento?.self, forKey: .interruption) ?? nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(running, forKey: .running)
        try container.encode(configuration, forKey: .configuration)
        try container.encode(lastStretchTime, forKey: .lastStretchTime)
        try container.encode(totalMuting, forKey: .totalMuting)
        try container.encode(stretchMuting, forKey: .stretchMuting)
        try container.encode(interruption, forKey: .interruption)
    }
}

public struct RunningMemento: Codable {
    public var startTime: Date
    public var excluded: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case startTime = "start"
        case excluded = "excluded"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try container.decode(Date.self, forKey: .startTime)
        excluded = try container.decodeIfPresent(TimeInterval.self, forKey: .excluded) ?? 0
    }
    
    public init(startTime: Date, excluded: TimeInterval) {
        self.startTime = startTime
        self.excluded = excluded
    }
}
