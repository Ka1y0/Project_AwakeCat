import AppKit
import AwakeCatCore

enum CatStatusIcon {
    private static let canvasSize = NSSize(width: 18, height: 18)

    static func image(for state: AwakeState) -> NSImage {
        let eyeStyle: EyeStyle = switch state {
        case .normal:
            .closed
        case .awake:
            .open
        case .error:
            .error
        }
        let image = NSImage(size: canvasSize, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let outline = NSBezierPath()
            outline.move(to: NSPoint(x: 3.2, y: 5.5))
            outline.curve(
                to: NSPoint(x: 3.1, y: 10.6),
                controlPoint1: NSPoint(x: 2.6, y: 7.0),
                controlPoint2: NSPoint(x: 2.6, y: 9.2)
            )
            outline.line(to: NSPoint(x: 3.0, y: 14.2))
            outline.line(to: NSPoint(x: 6.2, y: 12.1))
            outline.curve(
                to: NSPoint(x: 11.8, y: 12.1),
                controlPoint1: NSPoint(x: 7.8, y: 13.0),
                controlPoint2: NSPoint(x: 10.2, y: 13.0)
            )
            outline.line(to: NSPoint(x: 15.0, y: 14.2))
            outline.line(to: NSPoint(x: 14.9, y: 10.6))
            outline.curve(
                to: NSPoint(x: 14.8, y: 5.5),
                controlPoint1: NSPoint(x: 15.4, y: 9.2),
                controlPoint2: NSPoint(x: 15.4, y: 7.0)
            )
            outline.curve(
                to: NSPoint(x: 3.2, y: 5.5),
                controlPoint1: NSPoint(x: 12.5, y: 3.5),
                controlPoint2: NSPoint(x: 5.5, y: 3.5)
            )
            outline.close()
            outline.lineWidth = 1.35
            outline.lineCapStyle = .round
            outline.lineJoinStyle = .round
            outline.stroke()

            switch eyeStyle {
            case .open:
                NSBezierPath(
                    ovalIn: NSRect(x: 5.85, y: 7.45, width: 1.35, height: 1.65)
                ).fill()
                NSBezierPath(
                    ovalIn: NSRect(x: 10.8, y: 7.45, width: 1.35, height: 1.65)
                ).fill()
            case .closed:
                let eyes = NSBezierPath()
                eyes.move(to: NSPoint(x: 5.65, y: 8.15))
                eyes.line(to: NSPoint(x: 7.45, y: 8.15))
                eyes.move(to: NSPoint(x: 10.55, y: 8.15))
                eyes.line(to: NSPoint(x: 12.35, y: 8.15))
                eyes.lineWidth = 1.25
                eyes.lineCapStyle = .round
                eyes.stroke()
            case .error:
                // A restrained one-eye-open expression is deliberately
                // distinct from both authoritative Normal and Awake glyphs.
                NSBezierPath(
                    ovalIn: NSRect(x: 5.85, y: 7.45, width: 1.35, height: 1.65)
                ).fill()
                let eye = NSBezierPath()
                eye.move(to: NSPoint(x: 10.55, y: 8.15))
                eye.line(to: NSPoint(x: 12.35, y: 8.15))
                eye.lineWidth = 1.25
                eye.lineCapStyle = .round
                eye.stroke()
            }

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = switch eyeStyle {
        case .closed:
            "AwakeCat normal"
        case .open:
            "AwakeCat awake"
        case .error:
            "AwakeCat error"
        }
        return image
    }

    private enum EyeStyle {
        case closed
        case open
        case error
    }
}
