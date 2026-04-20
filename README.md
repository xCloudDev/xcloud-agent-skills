# xcloud-agent-skills

Portable skills for xCloud agent workflows. Works with Claude Code, OpenCode, and any agent that reads markdown prompts.

Skills:

- [`xcloud-public-api`](plugins/xcloud-public-api/skills/xcloud-public-api/SKILL.md) — xCloud Public API usage.

## Install

**Claude Code (plugin marketplace):**

```
/plugin marketplace add xCloudDev/xcloud-agent-skills
/plugin install xcloud-public-api@xcloud-agent-skills
```

**OpenCode:**

```bash
cp plugins/xcloud-public-api/skills/xcloud-public-api/SKILL.md \
   ~/.config/opencode/command/xcloud-public-api.md
```

**Anything else:** copy `SKILL.md` into whatever prompt/rules directory your agent uses.

## API token

Create a token at `https://app.xcloud.host/settings/api-tokens`, then:

```bash
cp .env.example .env   # paste your token inside
set -a; source .env; set +a
```

Verify:

```bash
curl -sS -H "Authorization: Bearer $XCLOUD_API_TOKEN" \
  https://app.xcloud.host/api/v1/user | jq
```

Never commit `.env`.
