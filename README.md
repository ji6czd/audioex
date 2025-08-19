# audioex.sh: Audio extractor from Movie file

## 概要

`audioex.sh`は、Blu-rayビデオの.m2tsファイルやDVDの.VOBファイルから音声を無変換で抽出するシェルスクリプトです。ffmpegを使用して、音声の品質を保持したまま効率的に抽出を行います。

## 機能

- **無変換抽出**: 音声を再エンコードせずに抽出（品質劣化なし）
- **複数フォーマット対応**: Blu-ray (.m2ts) とDVD (.VOB) ファイルに対応
- **複数ストリーム対応**: 複数の音声ストリームから選択して抽出
- **詳細情報表示**: 音声ストリームの詳細情報を表示
- **適応的PCM変換**: 直接コピーできない場合は最適なPCM形式で抽出
- **自動ファイル名生成**: 出力ファイル名の自動生成
- **エラーハンドリング**: 包括的なエラー処理とユーザーフレンドリーなメッセージ

### 対応フォーマット

- 入力: .m2ts (Blu-ray BDAV), .VOB (DVD Video)
- 出力: .wav (PCM音声)
- 対応コーデック: PCM Blu-ray, DTS, AC3, MPEG Audio (MP2)など

## 事前準備

### 前提条件

下記の環境が必要です。

- ffmpeg（音声処理に必要）
- bash（シェル実行環境）

### macOSでのffmpegインストール

Homebrewを使用してffmpegをインストールします：

```bash
# Homebrewがインストールされていない場合は先にインストール
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ffmpegをインストール
brew install ffmpeg
```

### Linux系でのffmpegインストール

#### Ubuntu/Debian系

```bash
# パッケージリストを更新
sudo apt update

# ffmpegをインストール
sudo apt install ffmpeg
```

#### CentOS/RHEL/Fedora系

```bash
# CentOS/RHEL 8以降、Fedora
sudo dnf install ffmpeg

# 古いCentOS/RHEL 7の場合
sudo yum install epel-release
sudo yum install ffmpeg
```

#### Arch Linux

```bash
sudo pacman -S ffmpeg
```

### 実行権限の付与

```bash
chmod +x audioex.sh
```

## 使い方

### 基本的な使用法

```bash
# Blu-rayファイルから抽出
./audioex.sh input.m2ts [output.wav]

# DVDファイルから抽出
./audioex.sh input.vob [output.wav]
```

### オプション

- `-s NUM`: 音声ストリーム番号を指定（0から開始、デフォルト: 0）
- `-i`: ストリーム情報のみを表示（抽出は行わない）
- `-h`: ヘルプを表示

## コマンドサンプル

### 1. 基本的な抽出（デフォルトストリーム）

```bash
# Blu-rayファイル
./audioex.sh movie.m2ts
# 出力: movie.wav

# DVDファイル
./audioex.sh VTS_01_1.VOB
# 出力: VTS_01_1.wav
```

### 2. 出力ファイル名を指定

```bash
# Blu-rayファイル
./audioex.sh movie.m2ts extracted_audio.wav

# DVDファイル
./audioex.sh VTS_01_1.VOB japanese_audio.wav
```

### 3. 特定のストリームを選択

```bash
# Blu-rayファイル（ストリーム1を選択）
./audioex.sh -s 1 movie.m2ts japanese_audio.wav

# DVDファイル（ストリーム0を選択）
./audioex.sh -s 0 VTS_01_1.VOB english_audio.wav
```

### 4. ストリーム情報のみを表示

```bash
# Blu-rayファイルの情報表示
./audioex.sh -i movie.m2ts

# DVDファイルの情報表示
./audioex.sh -i VTS_01_1.VOB
```

### 5. ヘルプを表示

```bash
./audioex.sh -h
```

## 実行例

```bash
$ ./audioex.sh -i movie.m2ts

Analyzing audio streams in 'movie.m2ts'...

Available audio streams:
  Stream 0 (index 1): pcm_bluray, 2ch, 48000Hz, 24bit, stereo
  Stream 1 (index 2): pcm_bluray, 6ch, 48000Hz, 24bit, 5.1(side)
  Stream 2 (index 3): dts, 6ch, 48000Hz, N/Abit, 5.1(side)

Total audio streams: 3

Detailed stream information:

--- Stream 0 ---
  codec_name=pcm_bluray
  channels=2
  sample_rate=48000
  bits_per_sample=24
  channel_layout=stereo
  duration=7234.567000
  bit_rate=2304000

Use -s <stream_number> to select a specific stream for extraction.
```

## 注意事項

- 入力ファイルが存在することを事前に確認してください
- 大きなファイルの処理には時間がかかる場合があります
- 出力ファイルが既に存在する場合、上書きの確認が表示されます
- PCM以外のコーデックも抽出可能ですが、可能な限り無変換で抽出されます
- 変換対象のファイルの著作権やその他の法的な事項に反しないようご利用ください。

## ライセンス

このスクリプトはMITライセンスで提供されています。

## 追記

このスクリプトは、Claude Sonnet 4によって作成されました。READMEの殆どもClaudeによって書かれました。人間Seikenはコードレビューとテストのみを行いました。改めてSonnetの実力と面白さを実感いたしました。
