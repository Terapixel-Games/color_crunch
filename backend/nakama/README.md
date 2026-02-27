# Color Crunch Nakama Backend

This folder provides a local Nakama backend for Color Crunch with:

- User authentication hooks (custom + device).
- Per-user high score tracking.
- Global high score leaderboard.
- Optional Terapixel platform integration webhooks.
- Terapixel platform proxy RPCs (B1 pattern: client -> Nakama -> platform).

## Files

- `backend/nakama/docker-compose.yml`: Local CockroachDB + Nakama stack.
- `backend/nakama/local.yml`: Nakama runtime config.
- `backend/nakama/modules/colorcrunch.js`: Runtime module with hooks and RPCs.
- `backend/nakama/render/start.sh`: Container startup script (migrations + nginx proxy).
- `backend/nakama/render/nginx.conf.template`: Single-port reverse proxy config.
- `backend/nakama/cloudrun/service.template.yaml`: Cloud Run service template.
- `backend/nakama/cloudrun/README.md`: Cloud Run deploy steps.

## Run Locally

1. `cd backend/nakama`
2. `docker compose up --build`

Nakama ports:

- API: `http://localhost:7350`
- Console: `http://localhost:7351` (`admin` / `adminpassword`)

## Runtime Module Environment Variables

Set these in `backend/nakama/local.yml` under `runtime.env`:

- `TPX_PLATFORM_AUTH_URL`: Optional URL called before custom/device auth. Non-2xx blocks auth.
- `TPX_PLATFORM_EVENT_URL`: Optional URL called on auth success and score submit.
- `TPX_PLATFORM_API_KEY`: Optional bearer token for both Terapixel endpoints.
- `TPX_PLATFORM_TELEMETRY_EVENTS_URL`: Optional telemetry ingest endpoint (`POST /v1/telemetry/events`) used by `tpx_client_event_track`.
- `TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL`: `POST /v1/auth/nakama`
- `TPX_PLATFORM_IAP_VERIFY_URL`: `POST /v1/iap/verify`
- `TPX_PLATFORM_IAP_ENTITLEMENTS_URL`: `GET /v1/iap/entitlements`
- `TPX_PLATFORM_ACCOUNT_MERGE_CODE_URL`: `POST /v1/account/merge/code`
- `TPX_PLATFORM_ACCOUNT_MERGE_REDEEM_URL`: `POST /v1/account/merge/redeem`
- `TPX_PLATFORM_MAGIC_LINK_START_URL`: `POST /v1/account/magic-link/start`
- `TPX_PLATFORM_MAGIC_LINK_COMPLETE_URL`: `POST /v1/account/magic-link/complete` (optional/manual fallback)
- `TPX_PLATFORM_USERNAME_VALIDATE_URL`: `POST /v1/identity/internal/username/validate` (identity moderation source of truth)
- `TPX_PLATFORM_INTERNAL_KEY`: admin key used for internal platform endpoints (maps to platform `INTERNAL_SERVICE_KEY`)
- `TPX_MAGIC_LINK_NOTIFY_SECRET`: shared secret for platform callback RPC `tpx_account_magic_link_notify`
- `TPX_USERNAME_CHANGE_COST_COINS`: coin price after first free username set (default `300`)
- `TPX_USERNAME_BLOCKLIST`: optional blocked username tokens as CSV or JSON array. Example CSV: `admin,moderator,badword`; JSON: `["admin","moderator","badword"]`
- `TPX_USERNAME_MODERATION_FAIL_OPEN`: `true|false` fallback mode when platform moderation endpoint is unavailable (default `false`).
- `TPX_USERNAME_CHANGE_COOLDOWN_SECONDS`: cooldown between username changes (default `300`).
- `TPX_USERNAME_CHANGE_MAX_PER_DAY`: max successful username changes per rolling day window (default `3`).
- `TPX_GAME_ID`: game id sent to identity exchange (`color_crunch` default)
- `TPX_EXPORT_TARGET`: `ios`|`android`|`poki`|`crazygames`|`web` (used for provider selection; default `web`)
- `TPX_HTTP_TIMEOUT_MS`: HTTP timeout for Terapixel calls (default `5000`).
- `COLOR_CRUNCH_LEADERBOARD_ID`: Leaderboard ID (default `colorcrunch_high_scores`).

## Container Database Environment Variables (Render and Cloud Run)

`backend/nakama/render/start.sh` resolves DB config in this order:

1. `DB_ADDRESS` (preferred; accepts with or without `postgres://` prefix)
2. `DATABASE_URL`
3. `DB_USER` + `DB_PASSWORD` + `DB_HOST` + `DB_NAME` (+ optional `DB_PORT`, `DB_SSLMODE`, `DB_PARAMS`)

This supports shared Postgres infrastructure where multiple games connect to separate databases on a single Postgres instance.

In this repo's Render blueprint, `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASSWORD` are bound from the existing shared Render database service `terapixel-platform-db`, and `DB_NAME` defaults to `colorcrunch`.

## RPC Contract

### `tpx_submit_score`

Authenticated user only.

Request:

```json
{
  "score": 1000,
  "subscore": 12,
  "metadata": { "track": "neo_city" }
}
```

Response:

```json
{
  "leaderboardId": "colorcrunch_high_scores",
  "record": { "...": "nakama leaderboard record" }
}
```

### `tpx_get_my_high_score`

Authenticated user only.

Request: `{}` or empty payload.

Response:

```json
{
  "leaderboardId": "colorcrunch_high_scores",
  "highScore": { "...": "owner leaderboard record or null" },
  "playerStats": {
    "bestScore": 1000,
    "bestSubscore": 12,
    "rank": 5
  }
}
```

### `tpx_list_leaderboard`

Public list.

Request:

```json
{
  "limit": 25,
  "cursor": ""
}
```

Response:

```json
{
  "leaderboardId": "colorcrunch_high_scores",
  "records": [],
  "nextCursor": "",
  "prevCursor": "",
  "rankCount": 0
}
```

## Auth for Clients

Clients should authenticate with Nakama normally (device/custom). This module adds:

- Optional pre-auth verification against `TPX_PLATFORM_AUTH_URL`.
- Auth success event emission to `TPX_PLATFORM_EVENT_URL`.

If the Terapixel auth URL is unset, Nakama auth proceeds without external verification.

## Platform Proxy RPCs

- `tpx_iap_purchase_start`: proxies purchase verification to platform.
- `tpx_iap_get_entitlements`: returns latest platform entitlements.
- `tpx_iap_sync_entitlements`: forces platform entitlement refresh.
- `tpx_account_merge_code`: creates pairing code for current user.
- `tpx_account_merge_redeem`: redeems pairing code and merges account into primary.
- `tpx_account_magic_link_status`: reads completion state pushed from platform.
- `tpx_account_magic_link_notify`: platform callback endpoint (shared-secret protected; enforces `game_id` when provided).
- `tpx_account_username_status`: returns current username + free/paid rename policy.
- `tpx_account_update_username`: validates and updates username (first change free, then coins).
- `tpx_client_event_track`: ingests normalized client telemetry events through Nakama to platform telemetry.

## Deploy on Render (fallback)

Render is decommissioned as the primary hosting path. Keep this section for disaster recovery only.
To re-enable GitHub-triggered fallback deploys, set repository/environment variable `RENDER_ENABLED=true`
and restore the required Render secrets (`RENDER_API_KEY`, `RENDER_SERVICE_IDS`).

This repo includes a Render Blueprint at `render.yaml` for a Docker-based Nakama web service that connects to a shared Postgres instance.

1. In Render, create a new Blueprint deployment from this repo.
2. Confirm the `colorcrunch-nakama` service is detected.
3. Confirm the shared Postgres service `terapixel-platform-db` exists in Render (or update `render.yaml` if your shared DB service has a different name).
4. Ensure database `colorcrunch` exists on that instance and the shared DB user can run Nakama migrations.
5. Optional override: set `DB_ADDRESS` directly if you want explicit connection-string control.
6. Set secrets that are marked `sync: false`:
   - `TPX_PLATFORM_AUTH_URL` (optional)
   - `TPX_PLATFORM_EVENT_URL` (optional)
   - `TPX_PLATFORM_API_KEY` (optional)
   - `NAKAMA_CONSOLE_PASSWORD` (recommended)
7. Deploy.

The Render startup script (`backend/nakama/render/start.sh`) runs migrations, starts Nakama on internal ports, and fronts it with nginx on Render's public `PORT`.

On Render:

- API/Client endpoints: `https://<your-service>.onrender.com/`
- Console: `https://<your-service>.onrender.com/console/`

## Deploy on Cloud Run

Cloud Run deployment scaffolding is included under `backend/nakama/cloudrun/`.

1. Build and push the image with `backend/nakama/Dockerfile.render`.
2. Create the required secrets (including `nakama-db-address` for shared Postgres).
3. Render `backend/nakama/cloudrun/service.template.yaml` placeholders and apply with `gcloud run services replace`.

Use `backend/nakama/cloudrun/README.md` for exact commands.
