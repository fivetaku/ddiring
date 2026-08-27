[English](README.md) | [한국어](README.ko.md) | [中文](README.zh.md) | 日本語 | [Español](README.es.md)

# ddiring

<p align="center">
  <img src="assets/ddiring-hero-01.png" alt="ddiring" width="320">
</p>

> 「タスク完了」ではなく、**どのセッションが**終わったのかを教えてくれる通知。

iTerm、Cursor、セッションマネージャーにまたがって Claude Code のセッションを5〜10個動かしていると、素っ気ない「タスク完了」バナーでは結局ウィンドウを一つずつ探すはめになります。ddiring(ティリン — 韓国語の「ピコン!」)は、通知ひとつで3つの問いに答えます: **どのプロジェクトフォルダ**か(タイトル)、そのセッションが**どのターミナル/アプリ**にいるか(サブタイトル)、**何を頼んだ作業**か(本文 — 最後のプロンプトの70字要約)。macOS で `terminal-notifier` があれば、クリックでそのアプリへ直接ジャンプ。

[クイックスタート](#クイックスタート) • [なぜ-ddiring](#なぜ-ddiring) • [仕組み](#仕組み) • [主な機能](#主な機能) • [コマンド](#コマンド) • [動作要件](#動作要件)

---

## クイックスタート

### 1. マーケットプレイスを追加

```
/plugin marketplace add https://github.com/fivetaku/gptaku_plugins.git
```

### 2. インストール

```
/plugin install ddiring
```

### 3. Claude Code を再起動

(フックとコマンドは再起動後に登録されます。)

### 4. 使う

何もする必要はありません — これからはすべてのセッションが終わるたびに鳴ります:

- **✅ my-app** / *iTerm* / 「認証テストの flaky を直して CI 再実行」 — iTerm のあの作業が完了
- **⏸️ blog** / *Cursor* / 「権限待ち」 — あるセッションがあなたを待っている
- 通知クリック(macOS + `terminal-notifier`)でそのアプリにフォーカス

クリックでフォーカスしたい場合(任意):

```bash
brew install terminal-notifier
```

## なぜ ddiring

マルチセッション作業で繰り返される小さな苦痛: *何かが*終わったのに、標準の通知はどれがどこで終わったのか教えてくれない。セッション ID も役に立ちません — `a3f9c2` を見て「Warp で回していたあのリファクタリング」を思い出せる人はいない。ddiring は人間が実際に認識できる3つを見せます: フォルダ名、アプリ名、そして自分が打った最後のプロンプト。

## 仕組み

セッションが応答を終えると `Stop` フックが(権限/入力待ちは `Notification` フックが ⏸️ で)発火します。スクリプトは:

1. transcript の末尾をまず200KB、見つからなければ最大2MBまで読み、最後の**本物の**プロンプトを抽出 — ツール結果・システムタグ・割り込み表記はスキップ;
2. プロセス環境からホストアプリを識別 — macOS は `__CFBundleIdentifier`、Windows は環境変数の判定(`TERM_PROGRAM` → `WT_SESSION` → `ConEmuPID`、継承による誤検出を避けて内側の変数を優先);
3. 通知を発射: macOS は `terminal-notifier`(クリック可能)または `osascript`、Windows は PowerShell 5.1 の WinRT トースト。

フックはスクリプトをファイル経由で実行するため、マッピングの修正は**すでに起動中のセッションにも**即座に反映されます — 再起動不要。

## 主な機能

- **30種以上のアプリマッピング、リサーチで実測検証**(ローカル `Info.plist`・Homebrew cask 定義・公式リポジトリ設定): Terminal, iTerm2, VS Code (+Insiders), VSCodium, Cursor, Windsurf (Devin), Antigravity, Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode — さらに Claude Code セッションマネージャー: Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum。
- **tmux/Zellij パススルー** — 個別の検出ロジックはなく、継承されたホスト環境変数で表示します(開始時と別のアプリから attach した tmux サーバーは元のホストが表示されることがあります)。
- **デフォルトで静か** — 音量0.2の控えめな完了音。環境変数でミュート/調整。
- **Windows サポート(実験的)** — Git Bash フック経路からの PowerShell トースト。トースト自体は追加インストール不要ですが、プロンプト抽出には Python 3 が必要です(なければ固定文言)。表示のみ、実機未検証 — 報告歓迎。
- **未知のアプリも安全に** — `TERM_PROGRAM` または生のバンドル ID をそのまま表示。マッピング追加は1行。
- **「送信」ではなく「表示」を検証するセルフチェック** — 通知の送信に成功しても macOS が表示を握りつぶすことがある（画面共有・ミラーリング中、集中モード、通知許可なし）。音だけ鳴ってバナーが出ず、プラグインの故障に見える。`/ddiring 診断` はテスト通知を送り、OS 自身の判定を読んで実際に表示されたか、されなければ理由を示す。初回実行時に1度自動で走る。

## コマンド

| コマンド | 動作 |
|---|---|
| `/ddiring` | 現在の状態(環境変数設定、`terminal-notifier` の有無、検出されたターミナル) |
| `/ddiring test` | このセッションの transcript でテスト通知を発射 |
| `/ddiring 診断` | 通知は送信されるのに表示されない原因を診断（画面共有・ミラーリング、集中モード、権限） |
| `/ddiring volume 0.1` / `mute` | 音量変更 / ミュート |

### 設定

Claude 設定ファイルの `"env"` ブロックに設定すると、新しく開始するセッションから適用されます:

| 変数 | デフォルト | 意味 |
|---|---|---|
| `DDIRING_SILENT` | `0` | `1` = 音なしバナーのみ (macOS) |
| `DDIRING_VOLUME` | `0.2` | 0.0〜1.0 (macOS) |
| `DDIRING_SOUND` | `Glass.aiff` | `/System/Library/Sounds/*.aiff` の任意のもの (macOS) |
| `DDIRING_HIDE_BODY` | `0` | `1` = 本文を隠す(ロック画面・画面共有のプライバシー) |

> 注意: 通知本文は OS の通知センターとロック画面に残ります — 機密性の高いプロンプトを扱う場合は `DDIRING_HIDE_BODY=1` を設定してください。`/ddiring` の初回実行時に gptaku プラグイン共通の更新通知フックもインストールされます。

## 動作要件

- macOS(フルサポート)または Windows + Git Bash(実験的)。それ以外の OS では静かに何もしません
- `python3`(macOS に標準搭載)— transcript の解析用
- 任意: クリックフォーカス用の `terminal-notifier`(macOS)

## ライセンス

[MIT](./LICENSE) — [DISCLAIMER.md](./DISCLAIMER.md) もご覧ください。
