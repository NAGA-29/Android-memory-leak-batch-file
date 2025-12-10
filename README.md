# Android-memory-leak-batch-file

Androidアプリのメモリリーク調査用バッチ (Windows, adb 前提)。USB接続用 `run_log_usb.bat` と Wi-Fi接続用 `run_log_wifi.bat` の2本があり、基本的なログ内容は共通です。

## 取れるデータ（metrics_*.csv）
- iso_time: デバイスのISO日時。`date -Ins` が失敗する端末では `NA`。
- uptime_s: `/proc/uptime` 秒数。`iso_time` 取得不可時の時間軸代替。
- pid: プロセスID。
- pid_changed: プロセスIDが直近から変わったら1（再起動検知）。
- pss_kb: `dumpsys meminfo` の TOTAL PSS。
- native_heap_kb: `dumpsys meminfo` の Native Heap PSS。
- dalvik_heap_kb: `dumpsys meminfo` の Dalvik Heap PSS。
- graphics_kb: `dumpsys meminfo` の Graphics PSS。
- cpu_pct: `dumpsys cpuinfo` からのCPU%。
- proc_name: パッケージ名。
- memfree_kb: `/proc/meminfo` の MemFree（端末全体）。
- cached_kb: `/proc/meminfo` の Cached（端末全体）。
- swapfree_kb: `/proc/meminfo` の SwapFree（端末全体の空きスワップ）。
- swap_kb: プロセスの Swap。`/proc/<pid>/smaps_rollup` の Swap、なければ `/proc/<pid>/status` の VmSwap。
- swappss_kb: プロセスの SwapPss。`smaps_rollup` がある端末のみ取得、それ以外は `NA`。
- pgfault: `/proc/vmstat` の pgfault。
- pgmajfault: `/proc/vmstat` の pgmajfault。

### Swapの見方（簡潔版）
swap_kb: プロセスがスワップアウトしている総量（VmSwap相当）。
swappss_kb: スワップのプロポーショナル負荷（共有ページ按分）。`smaps_rollup` 対応端末のみ。
swapfree_kb: 端末全体の空きスワップ。枯渇に近づくと性能/安定性リスク。

これらがCSV行で記録されるので、Excel/SheetsやPythonでグラフ化・傾き計算が容易です。

## 付帯ログ
- `run_info_*.txt` : 端末モデル、ビルド、ABI、メモリ総量、OSバージョン、アプリversionName、BT/Wi-Fi状態、バッテリーレベルなどのメタ情報を起動時に1回だけ出力。
- `logcat_*.txt` : GC/ART/プロセス死亡などを含むlogcat。`LOGCAT_FILTER` でフィルタ変更可能。

## 共通パラメータ（両バッチともファイル先頭で設定）
- `PACKAGE` : 監視したいアプリのパッケージ名
- `BASE_LOG_DIR` : ログ出力先のベースディレクトリ（実際の出力は日付サブフォルダ配下）
- `INTERVAL_INITIAL` / `INITIAL_LOOPS` : 起動直後の短周期サンプリング（例: 60秒 × 20回）
- `INTERVAL` : 通常サンプリング間隔（例: 300秒）
- `LOGCAT_FILTER` : logcatフィルタ文字列

## run_log_usb.bat
- USB接続を自動検出（`DEVICE` が空の場合）。複数接続時や特定端末を指定したい場合は `DEVICE=<シリアル>` をセット。
- 以降の処理（メトリクス取得/CSV/logcat/メタ情報）はWi-Fi版と同じ。

## run_log_wifi.bat
- `DEVICE` に `192.168.x.x:5555` などのデバイスIPを指定。バッチ起動時に `adb connect` で接続確認を行う。
- 以降の処理はUSB版と同じ。

## 使い方（共通）
1) `PACKAGE` と `LOG_DIR` を自分の環境に合わせて設定。
2) USB版: 端末をUSB接続して実行（または `DEVICE=<シリアル>` を指定）。Wi-Fi版: 事前に `DEVICE=<IP>` をセットして実行。
3) バッチ起動で `run_info_*.txt` / `logcat_*.txt` / `metrics_*.csv` が `BASE_LOG_DIR\YYYYMMDD` 配下に生成される（起動日ごとにフォルダ分割）。
4) 長時間回す場合はディスク残量に注意し、必要なら `LOG_DIR` を端末・シナリオごとに分ける。

## 典型的な活用例
- 長時間（24–48h）で `pss_kb` の傾きを算出し、メモリリークを疑う単調増加を検出。
- `pid_changed` でプロセス再起動を検出し、logcatの該当時刻と突き合わせて原因を追跡。
- `pgmajfault` 増加や `memfree_kb` の減少でシステムプレッシャーを把握。
- CPU% とGCログ（logcat）を重ねてスパイク要因を確認。

## よくあるカスタマイズ
- サンプリング間隔を変更したい: `INTERVAL_INITIAL` / `INTERVAL` を調整。
- 端末ごとにログを分けたい: `LOG_DIR` をデバイス名・シナリオ名で分けて実行。
- logcatの粒度を増やしたい: `LOGCAT_FILTER` から `*:I` を外し、必要なタグを追加。

## 依存と前提
- Windows + adb がPATHに通っていること。
- 端末がUSBデバッグ許可済み、またはWi-Fiデバッグで接続可能な状態。
- `powershell` が利用できる（タイムスタンプ生成に使用）。
