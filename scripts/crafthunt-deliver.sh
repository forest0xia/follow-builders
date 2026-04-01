#!/bin/bash
# CraftHunt daily delivery script for follow-builders
# Runs the digest pipeline and delivers to CraftHunt listing
#
# Usage: Add to crontab:
#   3 8 * * * /Volumes/workplace/follow-builders/scripts/crafthunt-deliver.sh >> /Volumes/workplace/follow-builders/scripts/crafthunt.log 2>&1

set -euo pipefail

# Ensure PATH includes common install locations (cron has minimal PATH)
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CREDENTIALS_FILE="$HOME/.config/crafthunt/credentials_follow-builders.json"
TODAY=$(date -u +"%Y-%m-%d")
RUN_ID="daily-digest-${TODAY}"

# Read credentials
if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "ERROR: No credentials file found at $CREDENTIALS_FILE"
  exit 1
fi

LISTING_API_KEY=$(python3 -c "import json; d=json.load(open('$CREDENTIALS_FILE')); print(d['listings'][0]['api_key'])")
LISTING_ID=$(python3 -c "import json; d=json.load(open('$CREDENTIALS_FILE')); print(d['listings'][0]['id'])")

# Use claude to generate and deliver the digest
claude -p "$(cat <<EOF
You are the follow-builders agent. Do the following:

1. Read ~/.config/crafthunt/credentials_follow-builders.json for CraftHunt credentials
2. Run the digest pipeline: cd ${SKILL_DIR}/scripts && node prepare-digest.js 2>/dev/null
3. Remix the output into a bilingual (EN/CN interleaved paragraph by paragraph) digest following the SKILL.md instructions at ${SKILL_DIR}/SKILL.md
4. Deliver to CraftHunt:
   - POST https://crafthunt.ai/api/v1/deliver
   - X-API-Key: ${LISTING_API_KEY}
   - listing_id: ${LISTING_ID}
   - title: "AI Builders Digest — ${TODAY}"
   - run_id: "${RUN_ID}"
   - content: your remixed digest in markdown
5. Update the credentials file with last_delivered and last_run_id

Do NOT stop until the delivery is confirmed.
EOF
)"
