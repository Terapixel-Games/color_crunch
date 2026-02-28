# Nakama Game Backend Template

Scaffold for per-game Nakama backend repos using the Terapixel platform pattern:

- Client authenticates to Nakama.
- Nakama exchanges identity with platform (`/v1/auth/nakama`).
- Client calls game RPCs on Nakama only.
- Nakama proxies to platform for account/IAP/moderation flows.

## Included
- `render.yaml` blueprint skeleton
- `nakama/modules/index.js` minimal bridge RPCs
- `nakama/Dockerfile.render` Render runtime image
- `nakama/render/start.sh` startup + migration + nginx proxy
- `nakama/render/nginx.conf.template` single-port API+console proxy
- `nakama/cloudrun/service.template.yaml` Cloud Run service template
- `nakama/cloudrun/README.md` Cloud Run deployment runbook
- `nakama/docker-compose.yml` local CockroachDB + Nakama stack
- `nakama/local.yml` local runtime config
- `nakama/README.md` local backend runbook
- `nakama/tests/leaderboard_rpc.test.js` backend test placeholder

## Token Replacement
This template uses the following placeholders:

- `color_crunch`
- `color_crunch_high_scores`
- `color-crunch-dev-key`

`scripts/bootstrap-game.ps1` in ArcadeCore replaces these automatically.

## Required Env Vars
- `GAME_ID`
- `PLATFORM_IDENTITY_URL`
- `PLATFORM_ACCOUNT_MAGIC_LINK_START_URL` (`/v1/account/magic-link/start`)
- `PLATFORM_ACCOUNT_MAGIC_LINK_COMPLETE_URL` (`/v1/account/magic-link/complete`)
- `TPX_MAGIC_LINK_NOTIFY_SECRET` (must match platform notify secret)

## Optional Env Vars
- `PLATFORM_INTERNAL_KEY` (maps to platform `INTERNAL_SERVICE_KEY`)
- `PLATFORM_USERNAME_VALIDATE_URL` (`/v1/identity/internal/username/validate`)
- `PLATFORM_ACCOUNT_MERGE_CODE_URL` (`/v1/account/merge/code`)
- `PLATFORM_ACCOUNT_MERGE_REDEEM_URL` (`/v1/account/merge/redeem`)
- `LEADERBOARD_ID` (default `<game_id>_high_scores`)
- `USERNAME_CHANGE_COST_COINS` (default `300`)
- `USERNAME_CHANGE_COOLDOWN_SECONDS` (default `300`)
- `USERNAME_CHANGE_MAX_PER_DAY` (default `3`)
- `PLATFORM_TELEMETRY_EVENTS_URL` (`POST /v1/telemetry/events`; consumed by `tpx_client_event_track`)

## Deployment Modes

- Primary: Cloud Run (`.github/workflows/cloudrun-nakama-deploy.yml`)
- Fallback: Render (`.github/workflows/render-deploy.yml`, manual dispatch only)

## Onboarding Output

`scripts/bootstrap-from-manifest.ps1` generates:

- `backend/nakama/.env.cloudrun.generated` (GitHub environment variable scaffold for Cloud Run workflow inputs)
- `backend/nakama/.env.local.generated` (local runtime defaults)
- `backend/nakama/.env.render.generated` (Render fallback env scaffold)
