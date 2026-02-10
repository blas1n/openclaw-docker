---
name: cron-request
description: Manage scheduled (cron) jobs directly from the sandbox using the cron-rpc script.
metadata: { "openclaw": { "emoji": "⏰" } }
---

# Cron Management

## Overview

Use `node scripts/cron-rpc.mjs` via `exec` to manage OpenClaw cron jobs directly. No host access needed.

## Commands

### List jobs

```bash
node scripts/cron-rpc.mjs list
```

### Add a job

```bash
node scripts/cron-rpc.mjs add '{"name":"job-name","message":"what to do","every":"1h"}'
```

### Remove / enable / disable / run

```bash
node scripts/cron-rpc.mjs rm <id>
node scripts/cron-rpc.mjs enable <id>
node scripts/cron-rpc.mjs disable <id>
node scripts/cron-rpc.mjs run <id>
```

## Add job JSON options

| Field | Required | Example | Description |
|-------|----------|---------|-------------|
| `name` | yes | `"daily-news"` | Job name (lowercase, hyphenated) |
| `message` | yes | `"Summarize AI news"` | Instruction for the agent when job fires |
| `every` | pick one | `"1h"`, `"30m"` | Repeating interval |
| `cron` | pick one | `"0 9 * * *"` | 5-field cron expression |
| `at` | pick one | `"+20m"` | One-shot at time or offset |
| `tz` | no | `"Asia/Seoul"` | Timezone for cron expressions |
| `session` | no | `"main"` | Session target (default: `"isolated"`) |
| `enabled` | no | `false` | Create disabled (default: `true`) |
| `deleteAfterRun` | no | `true` | Auto-delete one-shot jobs |
| `model` | no | `"ollama/gpt-oss:20b"` | Model override |

## Example

User: "매일 아침 9시에 AI 뉴스 요약해줘"

```bash
node scripts/cron-rpc.mjs add '{"name":"daily-ai-news","message":"오늘의 AI 뉴스를 검색하고 주요 내용을 HTML로 정리해서 file-share 링크로 보내줘","cron":"0 9 * * *","tz":"Asia/Seoul"}'
```

## Guidelines

- Results are automatically delivered to Telegram (chat ID is pre-configured).
- Write clear `message` instructions — this is what the agent receives when the job fires.
- Use `list` to verify the job was created.
- Prefer `cron` expressions with `tz` for daily/weekly schedules.
