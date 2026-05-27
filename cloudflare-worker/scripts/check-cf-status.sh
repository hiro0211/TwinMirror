#!/usr/bin/env bash
# 画像生成タイムアウト遭遇時に、原因が「Cloudflare 側」か「Gemini 側」かを5秒で切り分けるための診断スクリプト。
# 使い方: bash cloudflare-worker/scripts/check-cf-status.sh
set -euo pipefail

WORKER_URL="${WORKER_URL:-https://twinmirror-gemini-proxy.arimurahiroaki40.workers.dev}"

bold() { printf "\033[1m%s\033[0m\n" "$*"; }

bold "==> Cloudflare 全体ステータス"
curl -sS https://www.cloudflarestatus.com/api/v2/status.json \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"  indicator: {d['status']['indicator']}  description: {d['status']['description']}\")"

bold "==> 進行中のスケジュール済みメンテナンス"
curl -sS https://www.cloudflarestatus.com/api/v2/scheduled-maintenances/active.json \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
ms = d.get('scheduled_maintenances', [])
if not ms:
    print('  なし')
for m in ms:
    print(f\"  [{m['impact']}] {m['name']}\")
    print(f\"    {m['scheduled_for']} -> {m['scheduled_until']}\")
    comps = [c['name'] for c in m.get('components', [])]
    if comps:
        print(f\"    影響: {', '.join(comps[:6])}{'…' if len(comps) > 6 else ''}\")
"

bold "==> 未解決インシデント"
curl -sS https://www.cloudflarestatus.com/api/v2/incidents/unresolved.json \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
ins = d.get('incidents', [])
if not ins:
    print('  なし')
for i in ins:
    print(f\"  [{i['impact']}/{i['status']}] {i['name']}\")
    if i['incident_updates']:
        print(f\"    最新: {i['incident_updates'][0]['body'][:200]}\")
"

bold "==> Worker 疎通テスト (3回計測)"
for n in 1 2 3; do
  curl -sS -o /dev/null \
    -w "  Try${n}: HTTP %{http_code}  TTFB %{time_starttransfer}s  total %{time_total}s\n" \
    -X POST -H "Content-Type: application/json" -H "X-Auth-Token: dummy" \
    -d '{"model":"gemini-2.5-flash-image"}' \
    "${WORKER_URL}/generate"
done

bold "==> 補足"
echo "  - HTTP 401 が返れば Worker ルーティング自体は正常（認証段階で短絡）"
echo "  - TTFB が 1s 以上なら Worker → CF 経路に異常の疑い"
echo "  - メンテナンス時間と障害遭遇時刻が重なれば、対策はリトライで時間を稼ぐのみ"
