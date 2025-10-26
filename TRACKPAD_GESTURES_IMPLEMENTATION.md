# トラックパッドジェスチャー機能の実装

## 実装内容

このブランチでは、LinearMouseに以下の2つのトラックパッドジェスチャー機能を追加しました：

### 1. トラックパッドのコーナータップ機能
- **左下をタップ**: `Command + ←`（前のページに戻る）
- **右下をタップ**: `Command + →`（次のページに進む）

### 2. 3本指スワイプ機能
- **3本指で左にスワイプ**: `Control + Tab`（次のタブ）
- **3本指で右にスワイプ**: `Control + Shift + Tab`（前のタブ）

## 実装ファイル

### 新規作成したファイル

1. **`LinearMouse/EventView/TrackpadGestureView.swift`**
   - トラックパッドのタッチ位置、スワイプ方向、指の本数を取得するクラス
   - IOHIDEventから生のトラックパッドデータを抽出

2. **`LinearMouse/EventTransformer/MultiFingerSwipeTransformer.swift`**
   - 複数本指のスワイプジェスチャーを検出してキーボードショートカットを実行
   - 指の本数とスワイプ方向の組み合わせで動作

3. **`LinearMouse/EventTransformer/CornerTapTransformer.swift`**
   - トラックパッドの4隅（左上、右上、左下、右下）でのタップを検出
   - 各コーナーに異なるキーボードショートカットを割り当て可能

### 変更したファイル

1. **`LinearMouse/LinearMouse-Bridging-Header.h`**
   - IOHIDイベントフィールドの定義を追加
   - デジタイザー（トラックパッド）関連の定数
   - スワイプマスク関連の定数
   - 新しいIOHID関数の宣言

2. **`LinearMouse/EventTransformer/EventTransformerManager.swift`**
   - トラックパッドデバイス検出時に新しいTransformerを自動追加
   - 実験的機能としてマーク

3. **`LinearMouse/EventTap/EventType.swift`**
   - ジェスチャーイベント（NSEvent.EventType.gesture）の監視を追加

## 技術詳細

### IOHIDEventフィールド

以下のフィールドを使用してトラックパッド情報を取得：

```c
// タッチ位置（0.0〜1.0の正規化座標）
kIOHIDEventFieldDigitizerX
kIOHIDEventFieldDigitizerY

// タッチ状態
kIOHIDEventFieldDigitizerTouch   // 物理的接触
kIOHIDEventFieldDigitizerPressure // 圧力

// スワイプ情報
kIOHIDEventFieldSwipeMask         // スワイプ方向のビットマスク
```

### 座標系

- **X座標**: 0.0（左端）〜 1.0（右端）
- **Y座標**: 0.0（下端）〜 1.0（上端）
- **コーナー判定**: 各端から25%の領域をコーナーとして扱う

### 指の本数検出

IOHIDEventの子イベント（デジタイザータイプ）をカウントして指の本数を推測します。

## ビルド方法

```bash
# プロジェクトルートで実行
xcodebuild -project LinearMouse.xcodeproj -scheme LinearMouse -configuration Debug

# または
make
```

## テスト方法

### 1. アプリのビルドと起動

```bash
xcodebuild -project LinearMouse.xcodeproj -scheme LinearMouse
# ビルド成果物を実行
open build/Release/LinearMouse.app
```

### 2. アクセシビリティ権限の付与

1. システム設定 > プライバシーとセキュリティ > アクセシビリティ
2. LinearMouseを追加して許可

### 3. 機能テスト

#### コーナータップのテスト

1. **Safariやブラウザを開く**
2. **トラックパッドの左下をタップ**
   - 期待される動作: 前のページに戻る（`Command + ←`が実行される）
3. **トラックパッドの右下をタップ**
   - 期待される動作: 次のページに進む（`Command + →`が実行される）

#### 3本指スワイプのテスト

1. **ブラウザで複数のタブを開く**
2. **トラックパッドで3本指を使って左にスワイプ**
   - 期待される動作: 次のタブに移動（`Control + Tab`が実行される）
3. **トラックパッドで3本指を使って右にスワイプ**
   - 期待される動作: 前のタブに移動（`Control + Shift + Tab`が実行される）

### 4. デバッグログの確認

コンソールアプリでログを監視：

```bash
log stream --predicate 'subsystem == "LinearMouse"' --level debug
```

期待されるログ出力：

```
TrackpadGestureView: Trackpad: X=0.123, Y=0.456, Touch=1, Pressure=0.789, Fingers=3, Swipes=left, Phase=began, Corner=none
MultiFingerSwipeTransformer: Detected 3-finger left swipe, executing shortcut: control+tab
MultiFingerSwipeTransformer: Successfully executed keyboard shortcut: control+tab
```

```
CornerTapTransformer: Tap down detected at corner: bottomLeft (X=0.123, Y=0.089, Pressure=0.567)
CornerTapTransformer: Corner tap detected at bottomLeft, executing shortcut: command+arrowLeft
CornerTapTransformer: Successfully executed keyboard shortcut: command+arrowLeft
```

## カスタマイズ方法

### キーボードショートカットの変更

`LinearMouse/EventTransformer/EventTransformerManager.swift`の176-200行目を編集：

```swift
// 3本指スワイプのカスタマイズ例
let swipeTransformer = MultiFingerSwipeTransformer(mappings: [
    .init(fingerCount: 3, direction: .left, keys: [.control, .tab]),      // 元の設定
    .init(fingerCount: 3, direction: .right, keys: [.control, .shift, .tab]), // 元の設定
    .init(fingerCount: 4, direction: .up, keys: [.control, .arrowUp]),    // 4本指上スワイプを追加
    .init(fingerCount: 4, direction: .down, keys: [.control, .arrowDown]) // 4本指下スワイプを追加
])

// コーナータップのカスタマイズ例
let cornerTapTransformer = CornerTapTransformer(mappings: [
    .init(corner: .bottomLeft, keys: [.command, .arrowLeft]),  // 元の設定
    .init(corner: .bottomRight, keys: [.command, .arrowRight]), // 元の設定
    .init(corner: .topLeft, keys: [.command, .w]),             // 左上タップでタブを閉じる
    .init(corner: .topRight, keys: [.command, .t])             // 右上タップで新規タブ
])
```

### 利用可能なキー

`Modules/KeyKit/Sources/KeyKit/Key.swift`を参照：

- **修飾キー**: `.command`, `.shift`, `.option`, `.control`
- **矢印キー**: `.arrowLeft`, `.arrowRight`, `.arrowUp`, `.arrowDown`
- **文字キー**: `.a`, `.b`, `.c`, ... `.z`
- **数字キー**: `.zero`, `.one`, ... `.nine`
- **ファンクションキー**: `.f1`, `.f2`, ... `.f12`
- **その他**: `.tab`, `.space`, `.enter`, `.escape`, `.delete`

## 既知の制限事項

1. **指の本数検出の精度**
   - IOHIDEventの子イベントから推測するため、完全に正確ではない可能性があります
   - 2本指と3本指の区別は比較的正確ですが、4本指以上は環境によって異なる場合があります

2. **コーナー判定領域**
   - 現在は各端から25%の領域をコーナーとして扱います
   - この値は調整可能（`TrackpadGestureView.swift`の`tapCorner`プロパティ）

3. **システムジェスチャーとの競合**
   - macOSのシステムジェスチャー設定と競合する可能性があります
   - システム設定 > トラックパッド でシステムジェスチャーを無効化することを推奨

4. **デバイス互換性**
   - Appleのトラックパッドで最も良く動作します
   - サードパーティ製トラックパッドでは動作が異なる可能性があります

## トラブルシューティング

### ジェスチャーが認識されない場合

1. **アクセシビリティ権限を確認**
   - システム設定でLinearMouseにアクセシビリティ権限が付与されているか確認

2. **ログを確認**
   ```bash
   log stream --predicate 'subsystem == "LinearMouse"' --level debug | grep -i trackpad
   ```

3. **システムジェスチャーを確認**
   - システム設定 > トラックパッド で競合するジェスチャーを無効化

4. **デバイスが認識されているか確認**
   - ログに "Added experimental trackpad gesture transformers" が出力されているか確認

### ビルドエラーが発生する場合

1. **依存関係を更新**
   ```bash
   xcodebuild -resolvePackageDependencies
   ```

2. **クリーンビルド**
   ```bash
   make clean
   make
   ```

## 今後の拡張案

- [ ] JSON設定ファイルでジェスチャーマッピングをカスタマイズ可能に
- [ ] UIでジェスチャー設定を変更できるようにする
- [ ] より多くのジェスチャータイプをサポート（ピンチ、ローテーションなど）
- [ ] 指の本数検出の精度向上
- [ ] ジェスチャーの速度や距離を考慮した高度な検出

## ライセンス

MIT License - Copyright (c) 2021-2025 LinearMouse

## 参考資料

- [IOHIDFamily - Apple Open Source](https://opensource.apple.com/source/IOHIDFamily/)
- [WebKit CGEvent SPI](https://github.com/WebKit/WebKit/blob/main/Tools/TestRunnerShared/spi/CoreGraphicsTestSPI.h)
- [LinearMouse Original Repository](https://github.com/linearmouse/linearmouse)
