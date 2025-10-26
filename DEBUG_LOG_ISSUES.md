# ログが表示されない問題のデバッグガイド

## 問題の症状

- `log stream` コマンドを実行してもLinearMouseのログが表示されない
- トラックパッドジェスチャーの動作が不明

## 診断手順（段階的チェック）

### 🔍 ステップ1: アプリケーションの起動確認

```bash
# LinearMouseが動いているか確認
ps aux | grep LinearMouse | grep -v grep
```

**期待される出力:**
```
username  12345  0.0  0.1  ... /path/to/LinearMouse.app/Contents/MacOS/LinearMouse
```

**✅ プロセスが見つかった場合:** ステップ2へ進む
**❌ プロセスが見つからない場合:**

```bash
# アプリを起動
open /path/to/build/Release/LinearMouse.app

# または
open ~/Downloads/LinearMouse.app

# クラッシュログを確認
log show --predicate 'eventMessage contains "LinearMouse"' --last 10m | grep -i crash
```

---

### 🔍 ステップ2: Bundle Identifierの確認

LinearMouseのBundle IDが何か確認します（ログのサブシステム名として使用されている）。

```bash
# LinearMouseのBundle IDを確認
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
  /path/to/LinearMouse.app/Contents/Info.plist
```

**期待される出力:**
```
com.linearmouse.LinearMouse
```

このBundle IDをメモしてください。

---

### 🔍 ステップ3: 正しいサブシステム名でログを確認

ステップ2で確認したBundle IDを使用してログを取得：

```bash
# Bundle IDをサブシステムとして使用
log stream --predicate 'subsystem == "com.linearmouse.LinearMouse"' --level debug

# または、部分一致で検索
log stream --predicate 'subsystem CONTAINS "LinearMouse"' --level debug

# または、プロセス名で検索
log stream --predicate 'process == "LinearMouse"' --level debug
```

**期待される出力:**
```
Filtering the log data using "subsystem == "com.linearmouse.LinearMouse""
Timestamp               Thread     Type        Activity  PID    TTL
2025-10-26 12:34:56.789 0x12345    Default     0x0       1234   0    LinearMouse: [DeviceManager] ...
```

**✅ ログが表示される場合:** ステップ5へ（トラックパッド関連のログを確認）
**❌ ログが表示されない場合:** ステップ4へ

---

### 🔍 ステップ4: アクセシビリティ権限の確認

LinearMouseはアクセシビリティ権限がないとイベントを監視できません。

#### 方法1: システム設定で確認

```
システム設定（System Settings）
  └─ プライバシーとセキュリティ（Privacy & Security）
      └─ アクセシビリティ（Accessibility）
          └─ LinearMouse にチェックが入っているか確認
```

#### 方法2: コマンドで確認

```bash
# アクセシビリティ権限を持つアプリの一覧を取得
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client FROM access WHERE service='kTCCServiceAccessibility';" 2>/dev/null

# または（macOS 13以降）
tccutil reset Accessibility com.linearmouse.LinearMouse
# → その後、アプリを再起動すると権限ダイアログが表示されるはず
```

#### 権限が付与されていない場合の対処:

1. **システム設定を開く**
2. **プライバシーとセキュリティ** > **アクセシビリティ**
3. **🔒をクリックしてロック解除**（パスワード入力）
4. **+ ボタン** をクリック
5. **LinearMouse.app を選択**
6. **チェックボックスをON**
7. **LinearMouseを再起動**

---

### 🔍 ステップ5: トラックパッド関連のログを確認

アプリが起動していて、基本的なログが出力されている場合、トラックパッド関連のログを確認：

```bash
# トラックパッドジェスチャーのログのみ表示
log stream --predicate 'subsystem CONTAINS "LinearMouse"' --level debug \
  | grep -i trackpad

# スワイプTransformerのログのみ
log stream --predicate 'subsystem CONTAINS "LinearMouse"' --level debug \
  | grep -i swipe

# コーナータップのログのみ
log stream --predicate 'subsystem CONTAINS "LinearMouse"' --level debug \
  | grep -i corner
```

**✅ ログが表示される場合:** 機能は動作しています
**❌ ログが表示されない場合:** ステップ6へ

---

### 🔍 ステップ6: トラックパッドデバイスが検出されているか確認

```bash
# デバイス検出のログを確認
log stream --predicate 'subsystem CONTAINS "LinearMouse"' --level debug \
  | grep -E "device|trackpad|Device"

# または過去のログから確認
log show --predicate 'subsystem CONTAINS "LinearMouse"' --last 5m \
  | grep -i "trackpad"
```

**期待される出力:**
```
LinearMouse: [DeviceManager] Device added: category=trackpad
LinearMouse: [EventTransformerManager] Added experimental trackpad gesture transformers
```

**❌ "Added experimental trackpad gesture transformers" が出ない場合:**

トラックパッドデバイスとして認識されていません。原因は：

1. **外部トラックパッドを使用している場合**
   - 一度接続を解除して再接続
   - 内蔵トラックパッドで試してみる

2. **デバイス判定の問題**
   - `Device.swift` でトラックパッド判定を確認

---

### 🔍 ステップ7: EventTransformerが呼び出されているか確認

```bash
# EventTransformerManagerのログを確認
log stream --predicate 'subsystem CONTAINS "LinearMouse"' --level debug \
  | grep -i "EventTransformer"
```

**期待される出力:**
```
LinearMouse: [EventTransformerManager] Initialize EventTransformer with scheme: ...
LinearMouse: [EventTransformerManager] Added experimental trackpad gesture transformers
```

**このログが出ない場合:**
- EventTransformerManagerが初期化されていない
- スキームマッチングでトラックパッドが除外されている

---

### 🔍 ステップ8: 手動でログ出力を追加（デバッグ用）

ログが全く出ない場合、コードに直接ログを追加してテスト：

#### `EventTransformerManager.swift` に追加:

```swift
// 176行目あたりの if device?.category == .trackpad { の前に追加
os_log(
    "DEBUG: Checking device category: %{public}@, isTrackpad: %d",
    log: Self.log,
    type: .info,
    String(describing: device?.category),
    device?.category == .trackpad ? 1 : 0
)

if device?.category == .trackpad {
    os_log("DEBUG: Adding trackpad gesture transformers", log: Self.log, type: .info)
    // ...
}
```

#### `TrackpadGestureView.swift` の `init` に追加:

```swift
init?(_ event: CGEvent) {
    self.event = event
    self.ioHidEvent = CGEventCopyIOHIDEvent(event)

    os_log("DEBUG: TrackpadGestureView init called", type: .info)

    guard ioHidEvent != nil else {
        os_log("DEBUG: ioHidEvent is nil", type: .info)
        return nil
    }

    os_log("DEBUG: TrackpadGestureView initialized successfully", type: .info)
}
```

再ビルドして実行：

```bash
xcodebuild -project LinearMouse.xcodeproj -scheme LinearMouse clean build
open build/Release/LinearMouse.app

# ログ確認
log stream --predicate 'process == "LinearMouse"' --level debug | grep DEBUG
```

---

## よくある問題と解決策

### 問題1: "Filtering the log data..." と表示されるが何も出ない

**原因:** サブシステム名が間違っている、またはログレベルが低い

**解決策:**
```bash
# より広範囲に検索
log stream --level debug | grep LinearMouse

# またはプロセスIDで絞り込み
PID=$(pgrep LinearMouse)
log stream --predicate "processID == $PID" --level debug
```

### 問題2: "Stream interrupted" または "Timeout" エラー

**原因:** ログの出力が多すぎる、またはシステムの負荷が高い

**解決策:**
```bash
# より具体的な条件で絞り込む
log stream --predicate 'subsystem == "com.linearmouse.LinearMouse" AND category == "TrackpadGestureView"' --level debug
```

### 問題3: 過去のログは見えるが、リアルタイムのログが見えない

**原因:** `log stream` の問題

**解決策:**
```bash
# 過去のログを表示（最新1分）
log show --predicate 'subsystem CONTAINS "LinearMouse"' --last 1m --info --debug

# トラックパッドを操作しながら、1秒ごとに更新
while true; do
  clear
  log show --predicate 'subsystem CONTAINS "LinearMouse"' --last 5s --info --debug | tail -20
  sleep 1
done
```

### 問題4: コンソールアプリでもログが見えない

**原因:** ログレベルの設定問題

**解決策:**

1. **コンソールアプリを開く**
2. **アクション** > **ログレベルを含める** > **デバッグメッセージ**
3. **アクション** > **情報メッセージを含める**
4. **検索フィールドに "LinearMouse" を入力**

---

## 最終手段: printデバッグ

ログシステムがどうしても動作しない場合：

```swift
// TrackpadGestureView.swift の init に追加
init?(_ event: CGEvent) {
    print("🔴 TrackpadGestureView init called")
    self.event = event
    self.ioHidEvent = CGEventCopyIOHIDEvent(event)

    guard ioHidEvent != nil else {
        print("🔴 ioHidEvent is nil")
        return nil
    }

    print("🔴 TrackpadGestureView initialized successfully")
}
```

Xcodeでアプリを実行し、Xcodeのコンソールで `🔴` を検索。

---

## チェックリスト

ログが表示されない問題を解決するために、以下を順番に確認してください：

- [ ] LinearMouseのプロセスが動いている (`ps aux | grep LinearMouse`)
- [ ] Bundle IDを確認した (`/usr/libexec/PlistBuddy ...`)
- [ ] 正しいサブシステム名でログを検索した
- [ ] アクセシビリティ権限が付与されている
- [ ] 過去のログが表示される (`log show --last 5m`)
- [ ] リアルタイムのログが表示される (`log stream`)
- [ ] トラックパッドデバイスが検出されている
- [ ] "Added experimental trackpad gesture transformers" が表示される
- [ ] デバッグログを追加してリビルドした

---

## サポート情報の収集

問題が解決しない場合、以下の情報を収集してください：

```bash
# システム情報
sw_vers

# LinearMouseのバージョンとBundle ID
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" /path/to/LinearMouse.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /path/to/LinearMouse.app/Contents/Info.plist

# プロセス情報
ps aux | grep LinearMouse | grep -v grep

# 最近のクラッシュログ
log show --predicate 'eventMessage contains "LinearMouse"' --last 30m | grep -i "crash\|error\|fatal"

# 過去5分のすべてのログ
log show --predicate 'subsystem CONTAINS "LinearMouse"' --last 5m > linearmouse_logs.txt

# アクセシビリティ権限の状態
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client, auth_value FROM access WHERE service='kTCCServiceAccessibility';" 2>/dev/null
```

この情報をGitHub Issueに添付して報告してください。
