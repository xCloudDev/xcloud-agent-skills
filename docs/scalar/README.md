# Scalar landing page

A [Scalar](https://github.com/scalar/scalar) guide for all nine xCloud agent
capabilities: `xcloud:wordpress`, `xcloud:troubleshoot`, `xcloud:performance`,
`xcloud:sites`, `xcloud:ssl`, `xcloud:deploy`, `xcloud:servers`, `xcloud:billing`
and `xcloud:account`.

It covers WordPress-first workflows (inspect, approve a supported change,
verify), ClawHub/Claude Code/portable installation, authentication, the GET-only
REST fallback and dashboard-only operations. It contains **no API endpoints**;
the full [xCloud API reference](https://app.xcloud.host/api/v1/docs) is linked
from the guide.

## Files

| File | Role |
|---|---|
| `guide.md` | Landing-page copy. The generator inserts the capability table at `{{CAPABILITIES}}`. |
| `build.mjs` | Generator and offline freshness check. Reads the plugin version, checks it against ClawHub metadata, and checks capability coverage against source skill directories. |
| `build.test.mjs` | Offline checks for the guide's core boundaries, stale output, version drift and capability additions/removals. |
| `xcloud-skills.openapi.json` | Generated OpenAPI 3.1 guide with empty `paths`. Do not edit by hand. |
| `index.html` | Static Scalar page that renders the generated JSON. |

## Edit and verify

1. Edit `guide.md` and, when capability coverage changes, the table in `build.mjs`.
   Use the root README and `plugins/xcloud/reference/capability-map.md` as the
   scope and transport-boundary references. Older API examples do not override
   the packaged GET-only REST restriction.
2. With Node.js 22, regenerate and validate offline:

   ```bash
   node docs/scalar/build.mjs
   node docs/scalar/build.mjs --check
   node --test docs/scalar/build.test.mjs
   ```

3. Commit the source and regenerated JSON together. CI runs the checks above.
   No credentials, network calls or live infrastructure changes are needed.

`--check` does not write files. A changed plugin/ClawHub version or capability
set cannot silently leave the generated guide stale.

## View locally

Serve the folder over HTTP; the browser cannot fetch the JSON through a local
`file://` URL:

```bash
python3 -m http.server -d docs/scalar 8080
```

Open <http://localhost:8080>. Scalar itself loads from the jsDelivr CDN, so the
browser preview needs network access even though generation and checks do not.
To pin Scalar, change the `@scalar/api-reference` script URL in `index.html`.

## Publish to the xCloud app

The app serves a separately copied artifact at **`/agent/skills`** (xCloud app
repository: `routes/web.php` → `agent.skills.docs`). Updating or merging this
repository alone does **not** update that page.

After regeneration, copy `docs/scalar/xcloud-skills.openapi.json` into the app
repository's `docs/agent/xcloud-skills.openapi.json` and release it through that
app's deployment process. The app's Blade view rewrites `app.xcloud.host` to the
request host so the API/MCP links resolve on the current deployment.

After deployment, check that `/agent/skills` displays the plugin's current
version, all nine capabilities, all installation paths and the GET-only REST
boundary. The source check cannot verify that a production copy was deployed.

## Static hosting

`index.html` and `xcloud-skills.openapi.json` are fully static. With GitHub Pages
configured for the `main` branch's `/docs` folder, the guide is served at
`https://<org>.github.io/<repo>/scalar/`. Keep the JSON beside `index.html`,
which fetches `./xcloud-skills.openapi.json`.
