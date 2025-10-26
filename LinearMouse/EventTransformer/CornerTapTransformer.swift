// MIT License
// Copyright (c) 2021-2025 LinearMouse

import Foundation
import os.log
import KeyKit

/// トラックパッドの特定のコーナー（角）をタップしたときにアクションを実行するTransformer
class CornerTapTransformer: EventTransformer {
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "CornerTapTransformer"
    )

    // MARK: - 設定

    /// コーナータップマッピング
    struct CornerMapping {
        let corner: TrackpadGestureView.TapCorner
        let keys: [Key]

        init(corner: TrackpadGestureView.TapCorner, keys: [Key]) {
            self.corner = corner
            self.keys = keys
        }
    }

    private let mappings: [CornerMapping]
    private let tapPressureThreshold: Double
    private let debounceInterval: TimeInterval

    // MARK: - 状態管理

    private var lastTapTime: Date?
    private var lastTapCorner: TrackpadGestureView.TapCorner?
    private var tapInProgress: Bool = false

    // MARK: - 初期化

    init(
        mappings: [CornerMapping],
        tapPressureThreshold: Double = 0.3,
        debounceInterval: TimeInterval = 0.3
    ) {
        self.mappings = mappings
        self.tapPressureThreshold = tapPressureThreshold
        self.debounceInterval = debounceInterval
    }

    /// 便利な初期化メソッド
    convenience init(bottomLeft: [Key], bottomRight: [Key]) {
        self.init(mappings: [
            CornerMapping(corner: .bottomLeft, keys: bottomLeft),
            CornerMapping(corner: .bottomRight, keys: bottomRight)
        ])
    }

    // MARK: - EventTransformer

    func transform(_ event: CGEvent) -> CGEvent? {
        // マウスボタンイベントのみ処理（トラックパッドタップはマウスボタンイベントとして届く）
        guard event.type == .leftMouseDown || event.type == .leftMouseUp else {
            return event
        }

        // トラックパッドジェスチャービューを作成
        guard let gestureView = TrackpadGestureView(event) else {
            return event
        }

        if event.type == .leftMouseDown {
            handleTapDown(gestureView)
        } else if event.type == .leftMouseUp {
            handleTapUp(gestureView)
        }

        return event
    }

    // MARK: - Private Methods

    private func handleTapDown(_ gestureView: TrackpadGestureView) {
        // コーナーを判定
        guard let corner = gestureView.tapCorner else {
            return
        }

        // デバウンス: 前回のタップから一定時間経過しているかチェック
        if let lastTime = lastTapTime, Date().timeIntervalSince(lastTime) < debounceInterval {
            os_log(
                "Tap debounced (too soon after last tap)",
                log: Self.log,
                type: .debug
            )
            return
        }

        tapInProgress = true
        lastTapCorner = corner

        os_log(
            "Tap down detected at corner: %{public}@ (X=%.3f, Y=%.3f, Pressure=%.3f)",
            log: Self.log,
            type: .info,
            corner.rawValue,
            gestureView.touchX,
            gestureView.touchY,
            gestureView.pressure
        )
    }

    private func handleTapUp(_ gestureView: TrackpadGestureView) {
        guard tapInProgress, let tapCorner = lastTapCorner else {
            return
        }

        // タップアップ時にも同じコーナーにいるか確認
        guard let currentCorner = gestureView.tapCorner, currentCorner == tapCorner else {
            os_log(
                "Tap cancelled (moved away from corner)",
                log: Self.log,
                type: .debug
            )
            tapInProgress = false
            return
        }

        // マッピングを検索
        if let mapping = findMapping(for: tapCorner) {
            os_log(
                "Corner tap detected at %{public}@, executing shortcut: %{public}@",
                log: Self.log,
                type: .info,
                tapCorner.rawValue,
                mapping.keys.map { $0.rawValue }.joined(separator: "+")
            )

            executeKeyPress(mapping.keys)
            lastTapTime = Date()
        }

        tapInProgress = false
    }

    private func findMapping(for corner: TrackpadGestureView.TapCorner) -> CornerMapping? {
        return mappings.first { $0.corner == corner }
    }

    private func executeKeyPress(_ keys: [Key]) {
        do {
            try KeySimulator.shared.press(keys: keys, tap: .cghidEventTap)
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
