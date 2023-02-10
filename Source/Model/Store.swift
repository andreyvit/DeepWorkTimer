import Foundation
import Blackbird

//protocol Store: AnyObject {
//    
//}
//

class Store {
    private let database: Blackbird.Database
    
    init(isTesting: Bool) throws {
        let path: String
        if isTesting {
            path = ":memory:"
        } else {
            let fileURL = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("com.tarantsov.DeepWorkTimer", isDirectory: true).appendingPathComponent("database.sqlite", isDirectory: true)
            try! FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            eventLog.debug("database: \(fileURL.path)")
            path = fileURL.path
        }
        database = try Blackbird.Database(path: path)
        Task {
            do {
                try await database.execute("CREATE TABLE IF NOT EXISTS interruptions(id INTEGER PRIMARY KEY, timestamp TEXT, reason TEXT)")
            } catch {
                fatalError("database init failed: \(String(reflecting: error))")
            }
        }
    }
    
    func recordInterruption(reason: String) async throws {
        try await database.query("INSERT INTO interruptions(timestamp, reason) VALUES (?, ?)", Date(), reason)
    }
}
