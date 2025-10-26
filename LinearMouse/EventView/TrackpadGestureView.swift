// MIT License
// Copyright (c) 2021-2025 LinearMouse

import Foundation
import os.log

/// トラックパッドジェスチャー情報を取得するビュークラス
class TrackpadGestureView {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "TrackpadGestureView"
    )

    let event: CGEvent
    private let ioHidEvent: IOHIDEventRef?

    init?(_ event: CGEvent) {
        self.event = event
        self.ioHidEvent = CGEventCopyIOHIDEvent(event)

        guard ioHidEvent != nil else {
            return nil
        }
    }

    // MARK: - タッチ位置

    /// タッチX座標（0.0〜1.0の正規化座標、左端=0.0、右端=1.0）
    var touchX: Double {
        guard let ioHidEvent else { return 0 }
        return IOHIDEventGetFloatValue(ioHidEvent, kIOHIDEventFieldDigitizerX)
    }

    /// タッチY座標（0.0〜1.0の正規化座標、下端=0.0、上端=1.0）
    var touchY: Double {
        guard let ioHidEvent else { return 0 }
        return IOHIDEventGetFloatValue(ioHidEvent, kIOHIDEventFieldDigitizerY)
    }

    // MARK: - タッチ状態

    /// 物理的にタッチしているか
    var isTouching: Bool {
        guard let ioHidEvent else { return false }
        return IOHIDEventGetFloatValue(ioHidEvent, kIOHIDEventFieldDigitizerTouch) > 0
    }

    /// タッチの圧力（0.0〜1.0）
    var pressure: Double {
        guard let ioHidEvent else { return 0 }
        return IOHIDEventGetFloatValue(ioHidEvent, kIOHIDEventFieldDigitizerPressure)
    }

    // MARK: - スワイプ検出

    /// スワイプ方向（複数の方向が同時に返される場合あり）
    var swipeDirections: [SwipeDirection] {
        guard let ioHidEvent else { return [] }

        // ナビゲーションスワイプイベントを取得
        guard let swipeEvent = IOHIDEventGetEvent(ioHidEvent, IOHIDEventType.navigationSwipe.rawValue) else {
            return []
        }

        let swipeMask = IOHIDEventGetIntegerValue(swipeEvent, kIOHIDEventFieldSwipeMask)
        var directions: [SwipeDirection] = []

        if swipeMask & Int64(IOHIDSwipeMask.swipeLeft.rawValue) != 0 {
            directions.append(.left)
        }
        if swipeMask & Int64(IOHIDSwipeMask.swipeRight.rawValue) != 0 {
            directions.append(.right)
        }
        if swipeMask & Int64(IOHIDSwipeMask.swipeUp.rawValue) != 0 {
            directions.append(.up)
        }
        if swipeMask & Int64(IOHIDSwipeMask.swipeDown.rawValue) != 0 {
            directions.append(.down)
        }

        return directions
    }

    /// 指の本数を取得（簡易実装）
    /// 注: IOHIDEventから直接タッチ数を取得するのは難しいため、
    /// CGEventのジェスチャーフェーズと組み合わせて推測する
    var fingerCount: Int {
        guard let ioHidEvent else { return 0 }

        // デジタイザー子イベントからタッチ数を推測
        guard let children = IOHIDEventGetChildren(ioHidEvent) as? [IOHIDEventRef] else {
            return 1 // デフォルトは1本指
        }

        // デジタイザータイプの子イベントをカウント
        let digitizerChildren = children.filter { child in
            IOHIDEventGetType(child) == kIOHIDEventTypeDigitizer
        }

        return max(digitizerChildren.count, 1)
    }

    // MARK: - ジェスチャーフェーズ

    var gesturePhase: CGSGesturePhase? {
        let phaseValue = event.getIntegerValueField(.gesturePhase)
        return CGSGesturePhase(rawValue: UInt8(phaseValue))
    }

    // MARK: - コーナー検出

    /// トラックパッドの4隅のどこをタップしているか
    var tapCorner: TapCorner? {
        guard isTouching else { return nil }

        let threshold = 0.25 // 隅の判定領域（25%）

        if touchY < threshold {
            // 下側
            if touchX < threshold {
                return .bottomLeft
            } else if touchX > (1.0 - threshold) {
                return .bottomRight
            }
        } else if touchY > (1.0 - threshold) {
            // 上側
            if touchX < threshold {
                return .topLeft
            } else if touchX > (1.0 - threshold) {
                return .topRight
            }
        }

        return nil
    }

    // MARK: - デバッグ

    func logGestureInfo() {
        let swipeStr = swipeDirections.map { $0.rawValue }.joined(separator: ",")
        let phaseStr = gesturePhase?.description ?? "none"
        let cornerStr = tapCorner?.rawValue ?? "none"

        os_log(
            "Trackpad: X=%.3f, Y=%.3f, Touch=%d, Pressure=%.3f, Fingers=%d, Swipes=%{public}@, Phase=%{public}@, Corner=%{public}@",
            log: Self.log,
            type: .info,
            touchX, touchY,
            isTouching ? 1 : 0,
            pressure,
            fingerCount,
            swipeStr,
            phaseStr,
            cornerStr
        )
    }
}

// MARK: - Supporting Types

extension TrackpadGestureView {
    enum SwipeDirection: String {
        case left = "left"
        case right = "right"
        case up = "up"
        case down = "down"
    }

    enum TapCorner: String {
        case topLeft = "topLeft"
        case topRight = "topRight"
        case bottomLeft = "bottomLeft"
        case bottomRight = "bottomRight"
    }
}

extension CGSGesturePhase: CustomStringConvertible {
    public var description: String {
        switch self {
        case .none: return "none"
        case .began: return "began"
        case .changed: return "changed"
        case .ended: return "ended"
        case .cancelled: return "cancelled"
        case .mayBegin: return "mayBegin"
        }
    }
}
