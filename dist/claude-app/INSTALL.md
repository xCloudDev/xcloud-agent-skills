# Using the xCloud Skills in the Claude app (claude.ai)

A step-by-step guide to installing the xCloud skills in **claude.ai** (web /
desktop) by uploading them as Skills.

> This is the **app** path. For the terminal, install the Claude Code plugin
> instead (see `docs/SKILLS-GUIDE.md`). The two are separate and can both be used.

---

## 0. Before you start — read this

The skills run inside claude.ai's **code-execution sandbox**. That sandbox has a
**fixed outbound network allowlist** (Anthropic, GitHub, package registries). It
does **not** include `app.xcloud.host`, and you generally **cannot add to it**
(only some Enterprise workspaces have egress controls).

**What that means in practice:**

- The skill will load, read your token, and build the request correctly.
- The actual API call may be **blocked at the network boundary** with:
  `Host not in allowlist: app.xcloud.host` → `HTTP 403`.
- This is a **platform limitation, not a skill bug**, and nothing in the skill
  can fix it.

So treat the app upload as: great for trying the skills and seeing the branded
UX, but **live API calls only work if your workspace's egress permits
`app.xcloud.host`**.

> **The clean solution on claude.ai is the official xCloud MCP connector** —
> it runs outside the sandbox, so no egress limit applies:
> **Settings → Connectors → Add custom connector** → name `xcloud`, URL
> `https://app.xcloud.host/mcp` → sign in with OAuth. 149 tools, one per
> eligible API operation, with per-action confirmation on destructive
> operations (or `https://app.xcloud.host/mcp/v2` for a 4-tool compact
> surface).
> Docs: <https://app.xcloud.host/mcp/docs>. Combine it with this skill zip for
> branded, routed workflows on top.

---

## 1. Prerequisites

- A claude.ai plan with **Skills / code execution** available (Pro, Max, Team, or
  Enterprise — exact availability varies; Free typically excludes it).
- An **xCloud API token** (created in step 3).
- The skill **zip** from this repo (built in step 2).

---

## 2. Build the zip

From the repo root:

```bash
bash dist/claude-app/build.sh
```

This produces **one** self-contained skill zip in `dist/claude-app/`:

```
xcloud-agent-skill.zip
```

It bundles everything — a router `SKILL.md` covering all five capability areas
(servers, sites, WordPress, SSL, account), the wrapper script, and all reference
files. **One upload installs everything.**

> claude.ai treats a zip as a single skill, so all capabilities ship as one
> `xcloud` skill (not five). That's why there's one zip, not five.

---

## 3. Create an xCloud API token

1. Open the **xCloud dashboard**.
2. Go to **Profile → API Tokens → Generate New Token**.
3. Choose the scopes you need:
   - `read:servers` — list/inspect servers
   - `read:sites` — list/inspect sites
   - `write:servers` / `write:sites` — make changes
   - `*` — full access
4. **Copy the token immediately** — it's shown only once.

---

## 4. Upload a skill to claude.ai

1. Open **claude.ai** → your **profile/avatar → Settings**.
2. Go to **Capabilities** (also labelled *Features* in some accounts) and find the
   **Skills** section. Make sure **code execution** is enabled.
3. Click **Add Skill → Upload** (or *Upload skill*).
4. Select **`dist/claude-app/xcloud-agent-skill.zip`**.
5. Confirm. The skill appears as **`xcloud`** and covers all five areas — servers,
   sites, WordPress, SSL, and account. One upload, everything installed.

> **Don't** use "Import from GitHub" for these — that imports the *Claude Code
> plugin* structure, whose shared wrapper lives outside each skill folder and
> won't be present in the app. Always **upload the zip** (`xcloud-agent-skill.zip`).

---

## 5. Use it

Start a new chat and describe what you want. Because the app has no
`settings.json`, you provide the token **in the conversation**:

> "Use this xCloud token for this session: `xxxxxxxx`. List my servers."

Claude will set the token in the sandbox, then run the skill. Example prompts:

- "List my xCloud servers."
- "Show the sites on my Frankfurt server."
- "Is the SSL on shop.example.com valid?"

You'll see the xCloud branding (startup banner + `via xcloud:…` footer) and, on
the first real API call, either your data **or** the egress `403` described in
section 0.

**Token safety:** anything pasted into chat is sent to Anthropic. Use a
short-lived, least-scope token, and revoke it from the xCloud dashboard when done.

---

## 6. Updating a skill later

Skills uploaded to claude.ai are a **snapshot** — they don't auto-update from the
repo. To get changes:

1. Rebuild: `bash dist/claude-app/build.sh`
2. In claude.ai Settings → Skills, **remove** the old skill (re-upload doesn't
   always overwrite cleanly).
3. **Upload** the freshly built zip again.

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Host not in allowlist: app.xcloud.host`, `403` | Sandbox egress blocks your API | Add the xCloud MCP connector (`https://app.xcloud.host/mcp`) — it bypasses the sandbox — or use Claude Code |
| "no scripts/ … xcloud.sh not found" | You imported the GitHub **plugin**, not the zip | Remove it; upload the zip from `dist/claude-app/` |
| "XCLOUD_API_TOKEN not set" | No token provided | Paste the token in the chat (section 5) |
| `401` after pasting a token | Token expired/revoked/typo | Generate a new token |
| `403` *with* a valid token (not egress) | Missing scope/team permission | Grant the scope (e.g. `read:servers`) |
| Skill option missing in Settings | Code execution / Skills not enabled on your plan | Check plan; enable code execution |

---

## 8. Which surface should I use?

| | Claude Code (CLI) | claude.ai app |
|---|---|---|
| Install | Plugin via marketplace | Upload `xcloud-agent-skill.zip` |
| Token | `~/.claude/settings.json` (persistent) | Paste in-session |
| Local xCloud (`xcloud.test`) | ✅ works | ❌ unreachable from cloud |
| Live API (`app.xcloud.host`) | ✅ works | ⚠️ only if egress allows it |
| Best for | Real day-to-day use | Trying the skills / branded UX |

For robust xCloud access inside the Claude app, use the **official xCloud MCP
connector** (`https://app.xcloud.host/mcp` — see
[MCP docs](https://app.xcloud.host/mcp/docs)) — it cleanly bypasses the sandbox
network limit and works across the app, Claude Code, and the API.
