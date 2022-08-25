import Foundation

public struct TitleScheme {
    public var intervalKindSymbols: [IntervalKind: String]
    public var endPrompt: [IntervalPurpose: String]
    
    public static var live = TitleScheme(
        intervalKindSymbols: [
            .work(.leveragedDeep): "🔥", // ⏫💗🔥🍾🎉
            .work(.deep): "🧑🏼‍💻",
            .work(.shallow): "💬",
            .rest: "🌴",
        ], endPrompt: [
            .work: NSLocalizedString("BREAK", comment: ""),
            .rest: NSLocalizedString("WORK", comment: ""),
        ]
    )
    
    public static var test = TitleScheme(
        intervalKindSymbols: [
            .work(.leveragedDeep): "L",
            .work(.deep): "D",
            .work(.shallow): "S",
            .rest: "R",
        ], endPrompt: [
            .work: "BREAK",
            .rest: "WORK",
        ]
    )
}
