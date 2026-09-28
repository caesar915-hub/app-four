import CoreGraphics
import Testing
@testable import app_four

struct MoodBubbleLayoutTests {
    @Test func diameterIsLinearFromTheFloor() {
        #expect(MoodBubbleLayout.diameter(fraction: 0) == 60)
        #expect(MoodBubbleLayout.diameter(fraction: 0.2) == 86)
    }

    @Test func diameterClampsToTheCard() {
        #expect(MoodBubbleLayout.diameter(fraction: 0.5) == 110)
        #expect(MoodBubbleLayout.diameter(fraction: 1) == 110)
        #expect(MoodBubbleLayout.diameter(fraction: -1) == 60)
    }

    @Test func centresSitInFiveColumnsOnARisingBaseline() {
        let size = CGSize(width: 300, height: 180)
        let low = MoodBubbleLayout.center(level: 1, diameter: 60, in: size)
        let great = MoodBubbleLayout.center(level: 5, diameter: 60, in: size)
        #expect(low == CGPoint(x: 30, y: 142))
        #expect(great == CGPoint(x: 270, y: 90))
    }

    @Test func wideBubblesStayInsideTheChart() {
        let size = CGSize(width: 300, height: 180)
        let low = MoodBubbleLayout.center(level: 1, diameter: 110, in: size)
        let great = MoodBubbleLayout.center(level: 5, diameter: 110, in: size)
        #expect(low.x == 55)
        #expect(great.x == 245)
        #expect(MoodBubbleLayout.center(level: 3, diameter: 110, in: size).x == 150)
    }
}
