# MacOSでのビルドとテスト手順

このドキュメントでは、トラックパッドジェスチャー機能を実装したLinearMouseをMacOS上でビルド・テストする手順を説明します。

## 前提条件

### 必要な環境

- **OS**: macOS 11.0 (Big Sur) 以降
- **Xcode**: 13.0以降
- **Swift**: 5.5以降
- **トラックパッド**: Apple製トラックパッド（内蔵または Magic Trackpad）

### 事前インストール

```bash
# Homebrewがインストールされていない場合
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# swiftformatとswiftlintをインストール（オプション）
brew install swiftformat
brew install swiftlint
```

## ステップ1: リポジトリのクローン

```bash
# リポジトリをクローン
git clone https://github.com/tonote-lab/linearmouse-tonote.git
cd linearmouse-tonote

# 実装ブランチに切り替え
git checkout claude/trackpad-utility-research-011CUU5VeCg6jYL3nxzpXTBh
```

## ステップ2: プロジェクトのビルド

### 方法1: Xcodeを使用（推奨）

```bash
# Xcodeでプロジェクトを開く
open LinearMouse.xcodeproj
```

Xcode上で：
1. **Product** > **Scheme** > **LinearMouse** を選択
2. **Product** > **Build** (⌘B) でビルド
3. ビルドが成功することを確認

### 方法2: コマンドラインでビルド

```bash
# Debugビルド
xcodebuild -project LinearMouse.xcodeproj \
           -scheme LinearMouse \
           -configuration Debug \
           build

# Releaseビルド（配布用）
xcodebuild -project LinearMouse.xcodeproj \
           -scheme LinearMouse \
           -configuration Release \
           build
```

ビルド成果物の場所：
```
build/Release/LinearMouse.app
```

### 方法3: Makefileを使用

```bash
# すべて（lint, test, build, package）
make all

# ビルドのみ
make

# クリーンビルド
make clean
make
```

## ステップ3: テストの実行

### 単体テストの実行

```bash
# コマンドラインでテスト実行
xcodebuild test -project LinearMouse.xcodeproj \
                -scheme LinearMouse

# または
make test
```

Xcodeでテスト：
1. **Product** > **Test** (⌘U)
2. Test Navigatorでテスト結果を確認

### コードリントの実行（オプション）

```bash
# swiftformat
swiftformat --lint .

# swiftlint
swiftlint .

# または
make lint
```

## ステップ4: アプリケーションの起動

### 通常起動

```bash
# ビルド成果物を実行
open build/Release/LinearMouse.app

# またはXcodeから
# Product > Run (⌘R)
```

### デバッグモードで起動

Xcodeで：
1. **Product** > **Run** (⌘R)
2. コンソールでログを確認

## ステップ5: アクセシビリティ権限の付与

LinearMouseはシステムイベントを監視するため、アクセシビリティ権限が必要です。

### 手動での設定

1. **システム設定** を開く
2. **プライバシーとセキュリティ** をクリック
3. **アクセシビリティ** を選択
4. 🔒をクリックしてロック解除（パスワード入力）
5. **+** ボタンをクリック
6. `build/Release/LinearMouse.app` を追加
7. LinearMouseのチェックボックスをONにする

### 権限確認

アプリ起動時に権限がない場合、自動的にダイアログが表示されます。

## ステップ6: 機能テスト

### 6.1 コンソールログの監視

別のターミナルウィンドウを開いて、ログをリアルタイムで監視：

```bash
# LinearMouseのすべてのログを表示
log stream --predicate 'subsystem == "LinearMouse"' --level debug

# トラックパッド関連のみ
log stream --predicate 'subsystem == "LinearMouse"' --level debug | grep -i trackpad

# ジェスチャー関連のみ
log stream --predicate 'subsystem == "LinearMouse"' --level debug | grep -E 'Swipe|Corner'
```

### 6.2 コーナータップ機能のテスト

**テストケース1: 左下タップ**

1. **Safari** を起動
2. いくつかのページを閲覧（履歴を作る）
3. トラックパッドの**左下をタップ**
4. **期待される動作**: 前のページに戻る

**確認するログ:**
```
CornerTapTransformer: Tap down detected at corner: bottomLeft (X=0.123, Y=0.089, Pressure=0.567)
CornerTapTransformer: Corner tap detected at bottomLeft, executing shortcut: command+arrowLeft
CornerTapTransformer: Successfully executed keyboard shortcut: command+arrowLeft
```

**テストケース2: 右下タップ**

1. 前のページに戻った状態で
2. トラックパッドの**右下をタップ**
3. **期待される動作**: 次のページに進む

**確認するログ:**
```
CornerTapTransformer: Corner tap detected at bottomRight, executing shortcut: command+arrowRight
```

**コーナー判定の確認:**

トラックパッド上で指を動かしながらタップして、どの位置がコーナーとして認識されるか確認します。

- 左下コーナー: X < 0.25, Y < 0.25
- 右下コーナー: X > 0.75, Y < 0.25
- 左上コーナー: X < 0.25, Y > 0.75
- 右上コーナー: X > 0.75, Y > 0.75

### 6.3 3本指スワイプ機能のテスト

**テストケース1: 3本指左スワイプ**

1. **Google Chrome** または **Safari** を起動
2. 複数のタブを開く（タブ1、タブ2、タブ3）
3. タブ1を選択
4. トラックパッドで**3本指を使って左にスワイプ**
5. **期待される動作**: タブ2に移動

**確認するログ:**
```
TrackpadGestureView: Trackpad: X=0.456, Y=0.789, Touch=1, Pressure=0.812, Fingers=3, Swipes=left, Phase=began, Corner=none
MultiFingerSwipeTransformer: Detected 3-finger left swipe, executing shortcut: control+tab
MultiFingerSwipeTransformer: Successfully executed keyboard shortcut: control+tab
```

**テストケース2: 3本指右スワイプ**

1. タブ2が選択されている状態で
2. トラックパッドで**3本指を使って右にスワイプ**
3. **期待される動作**: タブ1に戻る

**確認するログ:**
```
MultiFingerSwipeTransformer: Detected 3-finger right swipe, executing shortcut: control+shift+tab
```

**スワイプ速度のテスト:**

- **ゆっくりスワイプ**: 認識されるか確認
- **速くスワイプ**: 認識されるか確認
- **短いスワイプ**: 最小限の動きで認識されるか確認

### 6.4 指の本数検出のテスト

異なる指の本数でスワイプして、正しく識別されるか確認：

```bash
# ログを監視しながら実行
log stream --predicate 'subsystem == "LinearMouse"' --level debug | grep "Fingers="
```

1. **2本指でスワイプ** → `Fingers=2` と表示される（アクションは実行されない）
2. **3本指でスワイプ** → `Fingers=3` と表示され、アクションが実行される
3. **4本指でスワイプ** → `Fingers=4` と表示される（アクションは実行されない）

### 6.5 システムジェスチャーとの競合テスト

macOSのシステムジェスチャーと競合しないか確認：

**システム設定の確認:**
1. **システム設定** > **トラックパッド**
2. 「その他のジェスチャ」タブを確認
3. 3本指でのスワイプが有効になっている場合、競合する可能性がある

**競合が発生する場合の対処:**

システムジェスチャーを無効化：
```
システム設定 > トラックパッド > その他のジェスチャ
- 「ページ間をスワイプ」: オフ
- 「フルスクリーンアプリケーション間をスワイプ」: 4本指に変更
```

## ステップ7: パフォーマンステスト

### CPU使用率の確認

```bash
# Activity Monitorでプロセスを監視
open -a "Activity Monitor"

# またはコマンドラインで
top -pid $(pgrep -f LinearMouse)
```

**期待される結果:**
- アイドル時: CPU使用率 < 1%
- ジェスチャー実行時: CPU使用率 < 5%

### メモリ使用量の確認

```bash
# メモリ使用量を確認
ps aux | grep LinearMouse | grep -v grep
```

**期待される結果:**
- メモリ使用量: < 100 MB

## ステップ8: エラーハンドリングのテスト

### 8.1 権限がない場合のテスト

1. システム設定でLinearMouseのアクセシビリティ権限を**オフ**にする
2. アプリを再起動
3. **期待される動作**: 権限要求ダイアログが表示される

### 8.2 トラックパッド未接続時のテスト

1. 外部トラックパッドを使用している場合、接続を解除
2. アプリの動作を確認
3. **期待される動作**: クラッシュせず、マウスモードで動作

### 8.3 連続タップのテスト

1. 同じコーナーを連続して素早くタップ（0.3秒以内）
2. **期待される動作**: デバウンスにより、最初のタップのみ認識

**確認するログ:**
```
CornerTapTransformer: Tap debounced (too soon after last tap)
```

## トラブルシューティング

### ビルドエラー

**エラー: "Command PhaseScriptExecution failed"**

```bash
# 依存関係を解決
xcodebuild -resolvePackageDependencies -project LinearMouse.xcodeproj

# クリーンビルド
rm -rf ~/Library/Developer/Xcode/DerivedData/LinearMouse-*
xcodebuild clean -project LinearMouse.xcodeproj -scheme LinearMouse
xcodebuild build -project LinearMouse.xcodeproj -scheme LinearMouse
```

**エラー: "No such module 'KeyKit'"**

```bash
# Swift Package Manager のキャッシュをクリア
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build

# Xcodeで File > Packages > Reset Package Caches
```

### ジェスチャーが認識されない

**問題: コーナータップが反応しない**

チェックリスト:
- [ ] アクセシビリティ権限が付与されているか
- [ ] ログに "Tap down detected" が出力されているか
- [ ] タップ位置がコーナー領域内か (X,Y座標を確認)

デバッグ用コマンド:
```bash
# タッチ座標をリアルタイム表示
log stream --predicate 'subsystem == "LinearMouse"' --level debug | grep "X=.*Y="
```

**問題: 3本指スワイプが認識されない**

チェックリスト:
- [ ] ジェスチャーイベント (type 29) が監視されているか
- [ ] システムジェスチャーと競合していないか
- [ ] ログに "Detected X-finger" が出力されているか

確認コマンド:
```bash
# ジェスチャーイベントの監視確認
log stream --predicate 'subsystem == "LinearMouse"' --level debug | grep -i gesture
```

**問題: 指の本数が正しく検出されない**

これは既知の制限です。IOHIDEventの子イベントから推測するため、環境によって異なる場合があります。

対処法:
1. ログで実際に検出されている指の本数を確認
2. 必要に応じて `TrackpadGestureView.swift` の `fingerCount` プロパティを調整

### ログが表示されない

```bash
# システムログ設定を確認
sudo log config --subsystem LinearMouse --mode level:debug

# または詳細ログを有効化
sudo log config --mode "level:debug"

# ログストリームを再起動
killall log
log stream --predicate 'subsystem == "LinearMouse"' --level debug
```

## テストチェックリスト

実装が正しく動作しているか、以下をチェック：

### ビルド
- [ ] Debugビルドが成功する
- [ ] Releaseビルドが成功する
- [ ] Lintエラーがない（警告は許容）
- [ ] 単体テストがすべてパスする

### コーナータップ
- [ ] 左下タップで `Command + ←` が実行される
- [ ] 右下タップで `Command + →` が実行される
- [ ] コーナー以外のタップでは反応しない
- [ ] 連続タップがデバウンスされる
- [ ] ログに適切なメッセージが出力される

### 3本指スワイプ
- [ ] 3本指左スワイプで `Control + Tab` が実行される
- [ ] 3本指右スワイプで `Control + Shift + Tab` が実行される
- [ ] 2本指スワイプでは反応しない
- [ ] 4本指スワイプでは反応しない（設定していない場合）
- [ ] ログに指の本数とスワイプ方向が正しく表示される

### パフォーマンス
- [ ] CPU使用率が正常範囲内
- [ ] メモリリークがない
- [ ] バッテリー消費が正常範囲内

### エラーハンドリング
- [ ] 権限がない場合、適切にエラー表示される
- [ ] トラックパッド未接続でもクラッシュしない
- [ ] 予期しないイベントでクラッシュしない

## ベンチマークテスト（オプション）

### レスポンス時間の測定

```bash
# テスト用スクリプトを作成
cat > test_response_time.sh << 'EOF'
#!/bin/bash
echo "Testing gesture response time..."
for i in {1..10}; do
  log stream --predicate 'subsystem == "LinearMouse"' --level debug | \
    grep -m 1 "Successfully executed" | \
    awk '{print $1, $2}'
done
EOF

chmod +x test_response_time.sh
./test_response_time.sh
```

**期待される結果:**
- ジェスチャー検出からアクション実行まで < 50ms

### 負荷テスト

1. 連続して50回ジェスチャーを実行
2. CPU使用率とメモリ使用量を監視
3. すべてのジェスチャーが正しく認識されることを確認

## DMGパッケージの作成（配布用）

```bash
# 署名証明書の設定（リリース用）
make configure-release

# パッケージの作成
make package

# 成果物の確認
ls -lh *.dmg
```

## 次のステップ

テストが完了したら：

1. **問題がない場合**
   - テスト結果をドキュメント化
   - プルリクエストをレビュー
   - メインブランチにマージ

2. **問題がある場合**
   - Issue を作成して報告
   - デバッグログを添付
   - 再現手順を詳細に記載

## 参考資料

- [LinearMouseオリジナルドキュメント](https://github.com/linearmouse/linearmouse)
- [Xcodeビルドガイド](https://developer.apple.com/documentation/xcode)
- [Swift Package Manager](https://swift.org/package-manager/)
- [IOHIDFamily API](https://developer.apple.com/documentation/iokit)

## サポート

問題が発生した場合：

1. このドキュメントのトラブルシューティングセクションを確認
2. `TRACKPAD_GESTURES_IMPLEMENTATION.md` の既知の制限事項を確認
3. GitHubでIssueを作成（ログとスクリーンショット添付）

---

**作成日**: 2025-10-26
**対象ブランチ**: `claude/trackpad-utility-research-011CUU5VeCg6jYL3nxzpXTBh`
**LinearMouseバージョン**: 開発版
