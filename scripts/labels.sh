#!/usr/bin/env bash
# Створює мітки машини станів у dopamine-shop. Потрібен gh з доступом до репо.
set -euo pipefail
REPO=Roman-Sharabura/dopamine-shop
while IFS='|' read -r name color desc; do
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
done <<'LABELS'
ai-ready|0E8A16|Спека готова, агенти можуть брати
ai-in-progress|1D76DB|Агенти працюють
ai-review|5319E7|PR чекає на людину
ai-needs-input|FBCA04|Питання до автора спеки
ai-blocked|B60205|Агенти зупинились, потрібна людина
LABELS
