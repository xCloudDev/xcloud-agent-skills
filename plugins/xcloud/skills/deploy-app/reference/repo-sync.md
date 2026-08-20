# Repository synchronization gate

xCloud deploys from a **Git repository it can read**, never from uncommitted
files sitting in a coding panel or local checkout. This gate runs before
`git_detect` and is the step most likely to fail for a project that lives in
Lovable, Replit, or another in-browser workspace — handle it explicitly instead
of assuming a repo is already in a deployable state.

## 1. Identify the remote

```bash
git remote -v
```

- No remote at all → **stop and ask.** Tell the user xCloud deploys from a Git
  host and ask them to create/connect a repository (GitHub, GitLab, etc.) or
  paste one they already have. Do not attempt any other transfer path.
- A remote exists → continue to step 2 with that URL.

## 2. Detect uncommitted or unpushed changes

```bash
git status --porcelain
git log '@{u}..HEAD' --oneline 2>/dev/null   # unpushed commits, if upstream is set
```

- Working tree clean and nothing unpushed → skip to step 4.
- Otherwise → continue to step 3.

## 3. Commit and push, with approval

Before running anything that mutates the user's repository:

- **Name every file** you are about to add/commit — never `git add -A`
  silently on a project you didn't fully generate yourself this session.
- State the target branch. Create a new branch instead of pushing to the
  current one if the user hasn't confirmed that's what they want.
- Get explicit approval, then:

```bash
git checkout -b deploy/xcloud   # or the user's chosen branch
git add <file> <file> ...
git commit -m "Prepare for xCloud deployment"
git push -u origin deploy/xcloud
```

If the push fails on auth, that's a panel/credential limitation — surface it
plainly rather than trying an alternate transport.

## 4. Verify xCloud can read that exact commit

Call `git_detect` (`POST /git/detect`) with the resolved `repository_url` (or
`provider_uuid` + `full_name`) and `branch`, and inspect
`repository_access.status`:

| Status | Meaning | Action |
|---|---|---|
| `accessible` | xCloud can read it | continue to detection |
| `inaccessible` | access problem, not a detection problem | follow `next_actions` — connect a provider, verify a deploy key, or make the repo public — then retry |

## Private repositories without a connected provider

A private SSH URL needs a deploy key prepared and verified **before** it can be
used in `git_detect`/`git/auto`:

1. `POST /servers/{uuid}/git/deploy-keys` — prepare a key.
2. Add the returned public key to the repository (the user does this — it
   needs repository admin access the coding panel may not have).
3. Verify the key.
4. Pass the adopted `deploy_key_uuid` alongside the private `git@…` URL.

If the panel cannot grant repository-admin access to add a deploy key, this is
a hard stop — tell the user exactly which step is blocked rather than
attempting a workaround.
