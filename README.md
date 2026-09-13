# EditPicture

ローカル Mac 上の ComfyUI を画像生成バックエンドとして使い、CLI/API から再現可能に操作するためのプロジェクトです。将来は、意味表現を中心にした prompt から FLUX や別バックエンド向け prompt を生成し、生成・評価・改善を自動化します。

モデル本体、参照画像、生成画像、ComfyUI 本体は GitHub に保存しません。

## 前提条件

- Apple Silicon Mac
- macOS、zsh
- Homebrew
- Git
- インターネット接続（初回のツールおよび ComfyUI インストール時のみ）

Python と `comfy-cli` は `scripts/setup.sh` が次の公式 CLI フローで用意します。

```bash
brew install uv
uv tool install --python 3.13 comfy-cli
```

Node.js / npm は使用しません。

必要な `comfy-cli` の最低バージョンは **1.13.0** です。background lifecycle の JSON 応答、`stop --dry-run`、Apple Silicon/uv install option を利用するため、`setup.sh` はバージョンと各 command の capability を検査します。古い場合は `uv tool upgrade comfy-cli` を実行してください。

## 新しい Mac でのセットアップ

```bash
git clone <repository-url> EditPicture
cd EditPicture
./scripts/setup.sh
```

`setup.sh` はディレクトリとローカル設定を作り、必要なら `uv`、`comfy-cli`、ComfyUI をインストールします。ComfyUI はリポジトリ外の次の場所に置かれます。

```text
~/.local/share/editpicture/comfy/ComfyUI
```

初回 install では親の `~/.local/share/editpicture/comfy` だけを作り、存在しない実体 path を clone 先として次を実行します。

```bash
comfy --workspace="$HOME/.local/share/editpicture/comfy/ComfyUI" install --m-series --fast-deps
```

既に同じ場所に `main.py`、`folder_paths.py`、`requirements.txt`、`comfy/` が揃っていれば再インストールしません。一部だけ存在する不完全な installation は上書きせず停止します。表示された directory を手動で退避してから再実行してください。モデルはダウンロードしません。生成される `comfy/config/runtime.env` と `comfy/config/extra_model_paths.yaml` は clone 固有の絶対パスを持つため Git から除外されます。

その後、必要なモデルを配置して起動します。

```bash
./scripts/start.sh
./scripts/healthcheck.sh
```

## モデル配置

用途に応じてファイルを以下へ手動で配置します。特定のモデル名やバージョンは固定していません。

| 用途 | 配置先 |
| --- | --- |
| 通常の checkpoint | `models/checkpoints/` |
| FLUX.1 系 diffusion model | `models/diffusion_models/` |
| Text encoder / CLIP / T5 | `models/text_encoders/` |
| VAE | `models/vae/` |
| LoRA | `models/loras/` |
| ControlNet | `models/controlnet/` |
| IP-Adapter | `models/ipadapter/` |
| IP-Adapter 用 vision encoder | `models/clip_vision/` |

ライセンスと組み合わせ要件を確認したうえで配置してください。モデルファイルはすべて `.gitignore` 対象です。

## 起動・停止・状態確認

起動:

```bash
./scripts/start.sh
```

デフォルト URL は `http://127.0.0.1:8188` です。外部ネットワークには公開しません。`start.sh` は `comfy-cli` のバックグラウンド起動を使い、`run/comfyui.pid` に PID を保存します。ComfyUI の継続的な runtime log は既定で `~/.local/share/editpicture/comfy/ComfyUI/user/comfyui_8188.log`、起動時の CLI JSON 応答は `logs/comfy-cli-launch.json` です。workspace や port を変更した場合、runtime log は `$COMFYUI_WORKSPACE/user/comfyui_$COMFYUI_PORT.log` になります。

状態確認:

```bash
./scripts/healthcheck.sh
```

`/system_stats` API を検査します。終了コードは `0` が正常、`1` が未起動または接続不能、`2` が HTTP/API 応答異常です。PID ファイルがなくても API が正常なら、別の方法で起動された正常な ComfyUI として報告します。

停止:

```bash
./scripts/stop.sh
```

保存 PID と `comfy-cli` の dry-run が特定した PID が一致した場合だけ停止します。他の Python プロセスを PID だけで kill しません。

ホストやポートをローカルで変更する場合は、`comfy/config/runtime.env` を編集します。設定の優先順位は「呼び出し時の環境変数 → `runtime.env` → 既定値」です。`COMFYUI_INSTALL_PARENT` だけを環境変数で指定すると、workspace はその直下の `ComfyUI` として導出されます。`start.sh` は安全のため loopback 以外の host を拒否します。

## データと workflow

- 再利用する ComfyUI API workflow JSON: `comfy/workflows/`
- 入力・参照画像: `input/`
- ComfyUI 生成画像: `output/`
- 実験設定・メモ: `experiments/`
- 大きな実験成果物: 各実験の `artifacts/` または `output/`

意味的な prompt とバックエンド固有 prompt は分離してください。将来は、小さな experiment 設定から workflow JSON を組み立て、生成結果と類似度評価を記録する Python パッケージを追加できるよう `pyproject.toml` を用意しています。

## Codex から画像生成する

このリポジトリには、ローカル ComfyUI を安全に使うための repo-local skill `editpicture-comfy-image` が含まれています。Codex には workflow を明示して、たとえば次のように依頼します。

```text
$editpicture-comfy-image を使い、comfy/workflows/flux-text-to-image.json で
「雨上がりの東京の路地」という画像を1枚生成してください。
モデルやbackendはworkflow指定から変更せず、出力を目視確認して実験記録を残してください。
```

workflow ファイル名は実際に `comfy/workflows/` へ配置したものへ置き換えてください。スキルはモデルを自動ダウンロードせず、cloudや有料APIへfallbackしません。workflowまたは必要モデルがなければ、その不足を報告して停止します。別のローカルモデルやworkflowへのfallbackも、ユーザーがその変更を明示承認した場合だけ行います。

Codexが直接 `comfy-cli` の機能を呼ぶ場合も、local-only設定を固定するラッパーを使います。

```bash
./scripts/comfy-local.sh --version
./scripts/comfy-local.sh system-stats
./scripts/comfy-local.sh run --workflow comfy/workflows/<workflow>.json --print-prompt
```

実行前には `./scripts/healthcheck.sh`、必要なら `./scripts/start.sh` を使います。生成ジョブの投入、有限時間の待機、ジョブ単位のキャンセル、目視確認、`experiments/<run-id>/` への来歴記録という詳しい手順は [skill本体](.agents/skills/editpicture-comfy-image/SKILL.md) にあります。

## Git 管理方針

Git で管理するもの:

- scripts、ドキュメント、`pyproject.toml`
- `comfy/workflows/` の再利用可能なテンプレート
- `comfy/config/` の `.example` 設定
- モデルや入出力用ディレクトリを維持する `.gitkeep`
- 小さな experiment 設定とメモ

Git で管理しないもの:

- 全モデルファイル
- `input/` と `output/` の内容
- logs、PID、Python cache、`.venv`
- clone 固有の runtime 設定
- 一時 workflow と大きな experiment 成果物
- 外部にインストールした ComfyUI 本体

## トラブルシューティング

### `uv` が見つからない

Homebrew を確認してから再実行します。

```bash
brew install uv
./scripts/setup.sh
```

### `comfy` が見つからない

uv の tool bin directory を PATH に反映し、zsh を再起動します。

```bash
uv tool update-shell
exec zsh
./scripts/setup.sh
```

### ComfyUI が起動しない

`logs/comfy-cli-launch.json` と `$COMFYUI_WORKSPACE/user/comfyui_$COMFYUI_PORT.log` を確認してください。ポート使用中、ComfyUI のインストール不完全、依存関係の問題を切り分けます。モデル未配置でもサーバーの起動と healthcheck は可能ですが、モデルを必要とする workflow の画像生成は失敗します。

### clone 場所を移動した

次を再実行すると、モデル参照用の絶対パス設定が現在の clone に更新されます。

```bash
./scripts/setup.sh
```

`runtime.env` は既存の明示設定を保持します。ComfyUI の場所も変更したい場合は、このファイルを編集してから再実行してください。
