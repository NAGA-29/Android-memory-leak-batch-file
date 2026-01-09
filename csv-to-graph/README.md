# CSV to Graph CLI

Android メモリメトリクス CSV ファイルをグラフ化する CLI ツールです。

## Features

- `metrics_*.csv` からメモリ使用量の時系列グラフを生成
- トレンドライン（線形回帰）と上昇率を表示
- PNG / PDF 出力対応
- Docker 環境で実行

## Quick Start

### Docker ビルド

```bash
cd csv-to-graph
docker build -t csv-to-graph .
```

### 基本的な使い方

```bash
# PDF 出力
docker run --rm -v /path/to/logs:/data csv-to-graph \
  --input /data/metrics_20250101_120000.csv \
  --output /data/graph.pdf

# PNG 出力
docker run --rm -v /path/to/logs:/data csv-to-graph \
  --input /data/metrics_20250101_120000.csv \
  --output /data/graph.png
```

### Windows での例

```powershell
docker run --rm -v C:\Users\yourname\memory_leak\20250101:/data csv-to-graph `
  --input /data/metrics_20250101_120000.csv `
  --output /data/graph.pdf
```

## Options

| オプション | 短縮 | 説明 | デフォルト |
|-----------|------|------|-----------|
| `--input` | `-i` | 入力 CSV ファイルパス | (必須) |
| `--output` | `-o` | 出力ファイルパス (.png, .pdf) | (必須) |
| `--metrics` | `-m` | 表示するメトリクス (カンマ区切り) | `native_heap_kb,dalvik_heap_kb` |
| `--no-trend` | - | トレンドラインを非表示 | (表示) |
| `--title` | `-t` | グラフタイトル | `Memory Usage Over Time` |
| `--figsize` | - | グラフサイズ (幅,高さ) | `12,6` |

## Examples

### 複数メトリクスを表示

```bash
docker run --rm -v /path/to/logs:/data csv-to-graph \
  --input /data/metrics.csv \
  --output /data/graph.pdf \
  --metrics native_heap_kb,dalvik_heap_kb,pss_kb,graphics_kb
```

### トレンドラインなし

```bash
docker run --rm -v /path/to/logs:/data csv-to-graph \
  --input /data/metrics.csv \
  --output /data/graph.png \
  --no-trend
```

### カスタムタイトルとサイズ

```bash
docker run --rm -v /path/to/logs:/data csv-to-graph \
  --input /data/metrics.csv \
  --output /data/graph.pdf \
  --title "App Memory Analysis - 24h Test" \
  --figsize 16,8
```

## Available Metrics

CSV に含まれる全メトリクス:

| メトリクス | 説明 |
|-----------|------|
| `pss_kb` | TOTAL PSS (Proportional Set Size) |
| `native_heap_kb` | ネイティブヒープメモリ |
| `dalvik_heap_kb` | Dalvik ヒープメモリ |
| `graphics_kb` | グラフィックスメモリ |
| `memfree_kb` | システム空きメモリ |
| `memavail_kb` | 実効確保可能メモリ |
| `cached_kb` | キャッシュメモリ |
| `swap_kb` | プロセスのスワップ使用量 |

## Output Example

グラフには以下が表示されます:

- 各メトリクスの時系列折れ線
- トレンドライン（破線）
- 凡例に上昇率 (KB/min または KB/h)

```
┌──────────────────────────────────────────────────┐
│  Memory Usage Over Time                          │
│                                                  │
│  ▲ KB                         ／ Native Heap     │
│  │                       ／──    (+2.3 KB/min)   │
│  │                  ／──                         │
│  │             ／──   ─── Dalvik Heap            │
│  │        ／──    ───       (+0.8 KB/min)        │
│  │    ／──   ───                                 │
│  └────────────────────────────────────▶ Time     │
│       09:00   10:00   11:00   12:00              │
└──────────────────────────────────────────────────┘
```

## Local Development (without Docker)

```bash
cd csv-to-graph
pip install -r requirements.txt
python cli.py --input ../sample.csv --output graph.pdf
```
