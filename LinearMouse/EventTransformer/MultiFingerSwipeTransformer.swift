// MIT License
// Copyright (c) 2021-2025 LinearMouse

import Foundation
import os.log
import KeyKit

/// 複数の指でのスワイプジェスチャーを検出してアクションを実行するTransformer
class MultiFingerSwipeTransformer: EventTransformer {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "MultiFingerSwipeTransformer"
    )

    // MARK: - 設定

    /// スワイプジェスチャーマッピング
    struct SwipeMapping {
        let fingerCount: Int
        let direction: TrackpadGestureView.SwipeDirection
        let keys: [Key]

        init(fingerCount: Int, direction: TrackpadGestureView.SwipeDirection, keys: [Key]) {
            self.fingerCount = fingerCount
            self.direction = direction
            self.keys = keys
        }
    }

    private let mappings: [SwipeMapping]

    // MARK: - 状態管理

    private var swipeHandled: Bool = false

    // MARK: - 初期化

    init(mappings: [SwipeMapping]) {
        self.mappings = mappings
    }

    /// 便利な初期化メソッド（単一マッピング用）
    convenience init(fingerCount: Int, direction: TrackpadGestureView.SwipeDirection, keys: [Key]) {
        self.init(mappings: [SwipeMapping(fingerCount: fingerCount, direction: direction, keys: keys)])
    }

    // MARK: - EventTransformer

    func transform(_ event: CGEvent) -> CGEvent? {
        // スクロールイベントまたはマウスイベントを処理
        guard event.type == .scrollWheel || 
              event.type == .leftMouseDragged || 
              event.type == .rightMouseDragged ||
              event.type == .otherMouseDragged else {
            return event
        }

        // トラックパッドジェスチャービューを作成
        guard let gestureView = TrackpadGestureView(event) else {
            return event
        }

        // スワイプ方向を取得
        let swipeDirections = gestureView.swipeDirections
        guard !swipeDirections.isEmpty else {
            // スワイプではない場合、状態をリセット
            swipeHandled = false
            return event
        }

        // ジェスチャーフェーズを確認
        guard let phase = gestureView.gesturePhase else {
            return event
        }

        // beganフェーズでスワイプを検出
        if phase == .began && !swipeHandled {
            let fingerCount = gestureView.fingerCount

            // 各スワイプ方向についてマッピングをチェック
            for direction in swipeDirections {
                if let mapping = findMapping(fingerCount: fingerCount, direction: direction) {
                    os_log(
                        "Detected %d-finger %{public}@ swipe, executing shortcut: %{public}@",
                        log: Self.log,
                        type: .info,
                        fingerCount,
                        direction.rawValue,
                        mapping.keys.map { $0.rawValue }.joined(separator: "+")
                    )

                    executeKeyPress(mapping.keys)
                    swipeHandled = true
                    break
                }
            }
        } else if phase == .ended || phase == .cancelled {
            // ジェスチャー終了時に状態をリセット
            swipeHandled = false
        }

        return event
    }

    // MARK: - Private Methods

    private func findMapping(
        fingerCount: Int,
        direction: TrackpadGestureView.SwipeDirection
    ) -> SwipeMapping? {
        return mappings.first { mapping in
            mapping.fingerCount == fingerCount && mapping.direction == direction
        }
    }

    private func executeKeyPress(_ keys: [Key]) {
        do {
            try KeySimulator.shared.press(keys: keys, tap: .cgSessionEventTap)
            os_log(
                "Successfully executed keyboard shortcut: %{public}@",
                log: Self.log,
                type: .info,
                keys.map { $0.rawValue }.joined(separator: "+")
            )
        } catch {
            os_log(
                "Failed to execute keyboard shortcut: %{public}@",
                log: Self.log,
                type: .error,
                error.localizedDescription
            )
        }
    }
}
