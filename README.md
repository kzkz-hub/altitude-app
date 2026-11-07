# altitude-app

現在地の標高をリアルタイムで表示する iPhone アプリです。
**ロック画面と Dynamic Island（ライブアクティビティ）** にも標高を出し続けるので、アプリを閉じても画面上で確認できます。

## 機能

- **標高の表示**：気圧計＋GPS（`CMAltimeter` の絶対高度）を優先して使い、使えない端末では GPS の高度を使います。推定誤差（±m）と測定ソースも表示します。
- **ロック画面と Dynamic Island に常時表示**：ライブアクティビティで標高を表示し続けます。
  - バックグラウンドでの位置情報更新を有効にしているので、ロック中も値が更新されます（ステータスバーに青い位置情報インジケータが出ます）。
  - 更新は「1m 以上変わったとき（最短 5 秒間隔）」か「60 秒ごと」です。電池の消費を抑えるため間引いています。
- **画面を常にオン**：スイッチを入れると、アプリ表示中は画面がスリープしません。

## 動作要件

- iOS 17 以降の iPhone（Dynamic Island 表示は iPhone 14 Pro 以降）
- macOS と Xcode 15 以降
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## ビルド手順

```bash
brew install xcodegen
xcodegen generate        # Altitude.xcodeproj を生成
open Altitude.xcodeproj
```

1. Xcode でターゲット `Altitude` と `AltitudeWidget` の **Signing & Capabilities** を開き、Team に自分の Apple ID を選びます（または `project.yml` の `DEVELOPMENT_TEAM` に Team ID を書きます）。
2. Bundle Identifier が他のアプリと重なるとエラーになるので、`project.yml` の `com.example.altitude` を自分専用の値（例：`com.yourname.altitude`）に変えて、もう一度 `xcodegen generate` を実行します。ウィジェット側は必ず `<アプリのID>.widget` にしてください。
3. iPhone を Mac につないで実行します。気圧計と GPS は**シミュレータでは正しく動かない**ので、実機で試してください。
4. 起動したら位置情報と「モーションとフィットネス」の利用を許可します。

## 構成

```
project.yml                          XcodeGen のプロジェクト定義
Shared/AltitudeActivityAttributes.swift  ライブアクティビティのデータ（アプリとウィジェットで共有）
Altitude/AltitudeApp.swift           アプリの入り口
Altitude/ContentView.swift           メイン画面
Altitude/AltitudeManager.swift       気圧計と GPS から標高を取得
Altitude/LiveActivityController.swift  ライブアクティビティの開始・更新・終了
AltitudeWidget/                      ロック画面と Dynamic Island の表示
```

## 注意事項

- iOS の仕様で、ライブアクティビティは**最長 8 時間**で自動的に終わります（その後最大 4 時間はロック画面に残ります）。続けて表示したいときは、アプリを開いてスイッチを入れ直してください。
- アプリをスワイプで完全に終了すると、バックグラウンドでの更新も止まります。最後の値はロック画面に残りますが、10 分たつと「更新停止中」と表示されます。
- 表示されるのは海抜の標高です。精度は環境によって変わり、GPS だけの場合は誤差が ±10m 以上になることもあります。
