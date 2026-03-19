# Onboarding Flow

Run this when `~/.follow-builders/config.json` does not exist or lacks `onboardingComplete: true`.

## Step 1: Introduction

Introduce the skill: you track AI builders on X and YouTube podcasts, delivering curated summaries.
Show actual counts from `config/default-sources.json` (e.g. "I track 25 builders on X and 4 podcasts").
Mention the source list is curated centrally and updates automatically.

## Step 2: Delivery Preferences

Ask frequency: Daily (recommended) or Weekly.
Ask preferred time and timezone (e.g. "8am, Pacific Time" → `"08:00"`, `"America/Los_Angeles"`).
For weekly, also ask which day.

## Step 3: Delivery Method

**If OpenClaw:** Skip this step. Set `delivery.method` to `"stdout"`.

**If non-persistent agent (Claude Code, Cursor, etc.):**

Offer three options:
1. **Telegram** — free, ~5 min setup
2. **Email** — requires a free Resend account
3. **On-demand** — no automatic delivery, just type `/ai`

**Telegram setup:**
1. User creates a bot via @BotFather on Telegram (`/newbot`)
2. User sends any message to the new bot (required for chat ID detection)
3. Get the token, then fetch the chat ID:
```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['message']['chat']['id'])" 2>/dev/null || echo "No messages found — make sure you sent a message to your bot first"
```
4. Save token in `.env`, chat ID in `config.json` under `delivery.chatId`

**Email setup:**
1. Ask for email address
2. User signs up at https://resend.com (free tier, 100 emails/day)
3. User creates an API key and adds it to the `.env` file

**On-demand:** Set `delivery.method` to `"stdout"`, skip cron later.

## Step 4: Language

Ask preference: English, Chinese, or Bilingual (interleaved EN/CN).

## Step 5: API Keys

**If stdout delivery:** No keys needed. Skip to Step 6.

**If Telegram or Email:** Create `.env` with only the relevant key:
```bash
mkdir -p ~/.follow-builders
cat > ~/.follow-builders/.env << 'ENVEOF'
# Telegram bot token (only if using Telegram delivery)
# TELEGRAM_BOT_TOKEN=paste_your_token_here

# Resend API key (only if using email delivery)
# RESEND_API_KEY=paste_your_key_here
ENVEOF
```
Uncomment only the line they need. Tell the user: content fetching is free and centralized — they only need a key for delivery.

## Step 6: Show Sources

Read `config/default-sources.json` and display the full list of tracked builders and podcasts.

## Step 7: Configuration Reminder

Tell the user all settings can be changed through conversation (e.g. "switch to weekly", "change timezone", "make summaries shorter").

## Step 8: Save Config & Set Up Cron

Save config:
```bash
cat > ~/.follow-builders/config.json << 'CFGEOF'
{
  "platform": "<openclaw or other>",
  "language": "<en, zh, or bilingual>",
  "timezone": "<IANA timezone>",
  "frequency": "<daily or weekly>",
  "deliveryTime": "<HH:MM>",
  "weeklyDay": "<day of week, only if weekly>",
  "delivery": {
    "method": "<stdout, telegram, or email>",
    "chatId": "<telegram chat ID, only if telegram>",
    "email": "<email address, only if email>"
  },
  "onboardingComplete": true
}
CFGEOF
```

Then set up the scheduled job:

### OpenClaw Cron

Build cron expression from preferences (e.g. daily 8am → `"0 8 * * *"`).

**IMPORTANT: Do NOT use `--channel last`.** It fails with multiple channels because isolated cron sessions have no "last" context. Always specify exact channel and target.

Ask the user: "Should I deliver to this same chat?" If yes, detect the channel name and target ID.

To find target IDs: run `openclaw logs --follow`, send a test message, and read the ID from logs. Or use channel-specific methods (`openclaw pairing list feishu`, Discord Developer Mode, etc.).

Create the cron job:
```bash
openclaw cron add \
  --name "AI Builders Digest" \
  --cron "<cron expression>" \
  --tz "<user IANA timezone>" \
  --session isolated \
  --message "Run the follow-builders skill: execute prepare-digest.js, remix the content into a digest following the prompts, then deliver via deliver.js" \
  --announce \
  --channel <channel name> \
  --to "<target ID>" \
  --exact
```

Verify it works:
```bash
openclaw cron list
openclaw cron run <jobId>
```

If it fails, check `openclaw cron runs --id <jobId> --limit 1`. Common errors:
- "Channel is required when multiple channels are configured" → specify exact channel
- "Delivering to X requires target" → add `--to`
- "No agent" → add `--agent <agent-id>`

Do NOT proceed until cron delivery is verified.

### Non-persistent + Telegram/Email

Use system crontab:
```bash
SKILL_DIR="<absolute path to the skill directory>"
(crontab -l 2>/dev/null; echo "<cron expression> cd $SKILL_DIR/scripts && node prepare-digest.js 2>/dev/null | node deliver.js 2>/dev/null") | crontab -
```
Note: this delivers raw JSON without LLM remixing. For full remixed digests, use `/ai` manually or switch to OpenClaw.

### Non-persistent + on-demand

Skip cron setup entirely.

## Step 9: Welcome Digest

**Do not skip.** Immediately generate and deliver the first digest using the Content Delivery workflow in SKILL.md.

After delivering, ask for feedback on length and focus. Then confirm:
- **Scheduled delivery:** "Your next digest arrives at [time]."
- **On-demand:** "Type /ai anytime for your next digest."

Apply any feedback to config.json or prompt files.
