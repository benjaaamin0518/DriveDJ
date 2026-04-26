# DriveDJ

![DriveDJ Logo](./DriveDJ_logo.png)

**DriveDJ** は、ドライブの状況に合わせて曲を自動で選ぶ iOS アプリです。  
「走る場所」「時間帯」「残り時間」などをもとに、今のドライブに合う音楽を流します。

## できること

- 走行状況に合わせてムードを判定
- Spotify のデータを使って候補曲を広げる
- Apple Music で再生する
- 再生中は定期的に次の曲を準備する
- ドライブの流れに合わせて曲の雰囲気を変える

## ざっくりした仕組み

```text
現在地・速度・天気・残り時間
→ ムード判定
→ Spotify で候補曲を取得
→ Apple Music で見つかった曲を再生
→ 1分おきに次の候補を更新
```

## 必要なもの

- Mac
- Xcode
- iPhone 実機
- Apple Music サブスクリプション
- Spotify Developer アカウント
- CarPlay 対応環境（将来的に使用）

## セットアップ

### 1. Xcode で新規プロジェクトを作成
- テンプレートは **iOS App**
- Interface は **SwiftUI**
- Language は **Swift**

### 2. コードを追加
このリポジトリの Swift ファイルを Xcode プロジェクトに追加します。  
`@main` を持つアプリファイルが 1 つだけ存在することを確認してください。

### 3. Signing を設定
- `Signing & Capabilities` で Team を選択
- `Automatically manage signing` を ON
- Bundle Identifier を自分専用のものに変更

例:
```text
com.yourname.drivedj
```

### 4. 追加する Capability
- Apple Music を使うための設定
- Background Modes の Audio
- 必要に応じて Location
- WeatherKit を使うなら WeatherKit

### 5. 権限文言を追加
`Info.plist` に用途説明を入れます。

例:
```xml
<key>NSAppleMusicUsageDescription</key>
<string>音楽を再生するためにApple Musicへアクセスします</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>走行状況と到着予測を取得するために位置情報を使用します</string>
```

## 使い方

1. アプリを起動
2. 位置情報や再生権限を許可
3. 目的地や走行状態を入力、または自動取得
4. アプリがムードを判定
5. 条件に合う曲が Apple Music で再生される

## 曲の選び方

DriveDJ は、次のような考え方で曲を選びます。

- **CHILL**: 落ち着いた曲
- **MID**: 普通のテンポの曲
- **UP**: 少し盛り上がる曲
- **PEAK**: ドライブが一番気持ちいい時間に合う曲
- **END**: 到着前に締める曲

Spotify の recommendations API を使うことで、seed 曲だけでなく、似た雰囲気の曲も候補に入れられます。

## 注意点

- Spotify は「候補曲を広げるため」に使います
- 再生は Apple Music 側で行います
- 実機の挙動は、シミュレータと少し違うことがあります
- CarPlay は通常の iPhone 画面より制約が多いです
- Apple Music に存在しない曲は再生できません

## 今後の改善案

- 曲候補のローカルキャッシュ
- 連続再生時の自然な切り替え
- ドライブログの保存
- よく聞くアーティストの学習
- CarPlay 向け UI の整理

## 開発メモ

このアプリは、次の 4 つに分けて考えると分かりやすいです。

1. **状態取得**  
   速度、残り時間、天気、位置情報を取る

2. **ムード判定**  
   状態から今の気分を決める

3. **曲選定**  
   Spotify で候補を広げ、Apple Music で再生可能な曲を選ぶ

4. **再生制御**  
   再生中なら 1 分おきに次の候補を更新する
