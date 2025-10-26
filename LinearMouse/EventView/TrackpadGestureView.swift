// MIT License
// Copyright (c) 2021-2025 LinearMouse

import Foundation
import os.log
import IOKit.hid

/// トラックパッドジェスチャー情報を取得するビュークラス
class TrackpadGestureView {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "TrackpadGestureView"
    )

    let event: CGEvent
    private let ioHidEvent: IOHIDEvent?

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
        // CGEventの基本的なスワイプ情報から判定
        let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
        
        var directions: [SwipeDirection] = []
        let threshold = 10.0 // スワイプ検出のしきい値
        
        if abs(deltaX) > threshold {
            if deltaX > 0 {
                directions.append(.right)
            } else {
                directions.append(.left)
            }
        }
        
        if abs(deltaY) > threshold {
            if deltaY > 0 {
                directions.append(.up)
            } else {
                directions.append(.down)
            }
        }
        
        return directions
    }

    /// 指の本数を取得（簡易実装）
    /// 注: CGEventから推測する簡易実装
    var fingerCount: Int {
        // CGEventからマルチタッチイベントの指の本数を取得を試みる
        // これは近似値であり、実際の値と異なる場合があります
        let eventType = event.type
        
        switch eventType {
        case .scrollWheel:
            // スクロールイベントの場合、デルタの大きさから推測
            let deltaX = abs(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
            let deltaY = abs(event.getDoubleValueField(.scrollWheelEventDeltaAxis2))
            
            if deltaX > 50 || deltaY > 50 {
                return 2 // 大きな動きは2本指と推定
            }
            return 1
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            return 2 // ドラッグイベントは通常2本指以上と推定
        default:
            return 1
        }
    }

    // MARK: - ジェスチャーフェーズ

    /// ジェスチャーフェーズ（簡易実装）
    var gesturePhase: GesturePhase? {
        let eventType = event.type
        
        // イベントタイプからジェスチャーフェーズを推測
        switch eventType {
        case .scrollWheel:
            // スクロールイベントの場合、継続中と仮定
            return .changed
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            // ドラッグイベントの場合も継続中と仮定
            return .changed
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return .began
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            return .ended
        default:
            return nil
        }
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
    enum SwipeDirection: String, CaseIterable {
        case left = "left"
        case right = "right"
        case up = "up"
        case down = "down"
    }

    enum TapCorner: String, CaseIterable {
        case topLeft = "topLeft"
        case topRight = "topRight"
        case bottomLeft = "bottomLeft"
        case bottomRight = "bottomRight"
    }
    
    enum GesturePhase: String, CaseIterable {
        case none = "none"
        case began = "began"
        case changed = "changed"
        case ended = "ended"
        case cancelled = "cancelled"
        case mayBegin = "mayBegin"
    }
}

extension TrackpadGestureView.GesturePhase: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
