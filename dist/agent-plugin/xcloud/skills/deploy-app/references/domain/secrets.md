# Secrets contract

`env_file_content` on `servers_sites_git_auto`/`servers_sites_git_docker` makes
it easy to forward a project's entire `.env` in one call. That ease is exactly
why this needs an explicit rule instead of a default behavior.

## May forward

- Non-secret build/runtime configuration (build command, port, framework
  flags).
- Values the user pastes **deliberately, in this turn**, in response to a
  named request for them.

## Must NOT do

- Bulk-read a local `.env` file and forward its contents automatically.
- Echo any secret value back into chat, into a log line, or into a git commit.
- Assume a value is safe to forward because it was already sitting in a local
  `.env` — the panel's secret store, not the working tree, is authoritative for
  anything the user marked as a secret there.

## Process

1. From `git_detect`'s framework/build output (or a manual scan when the user
   asks), determine the **names** of environment variables the app needs at
   build or runtime — not their values.
2. Classify each as build-time-public (e.g. a browser-exposed Supabase URL) or
   runtime-secret (API keys, database URLs, tokens).
3. Ask the user for the runtime-secret values by name, one request, rather than
   reading a `.env` file wholesale.
4. Build `env_file_content` from exactly the values the user supplied this
   turn. Do not carry forward values from a previous unrelated task.
5. On a retry (idempotent replay via `Idempotency-Key`), do not re-prompt for
   or re-log values already accepted — but never print them to confirm they
   "look right."

## Open item for the xCloud backend (tracked, not blocking this skill)

Today `env_file_content` is a plaintext body in the request. A write-only
submission mode or a secret-reference indirection (submit once, reference by
name on retry) would remove the need for this skill to hold plaintext secrets
in its own working state at all. File as a backend follow-up if the volume of
deploy-app usage makes it worth prioritizing — it does not block Phase 2.
