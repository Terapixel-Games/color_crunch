# Cloud Run Deployment (Color Crunch Nakama)

This folder contains a starter Cloud Run service spec for deploying the Nakama container with the same Postgres instance used by `terapixel-platform`.

## Files

- `backend/nakama/cloudrun/service.template.yaml`: Knative service template with placeholder values.

## 1) Build and push the container image

From the repo root:

```bash
PROJECT_ID="<gcp-project>"
IMAGE_URI="us-central1-docker.pkg.dev/${PROJECT_ID}/nakama/colorcrunch-nakama:$(git rev-parse --short HEAD)"

gcloud builds submit \
  --project "${PROJECT_ID}" \
  --tag "${IMAGE_URI}" \
  --file backend/nakama/Dockerfile.render \
  .
```

## 2) Create required secrets

Required secret names in the template:

- `nakama-db-address`
- `nakama-server-key`
- `nakama-session-encryption-key`
- `nakama-session-refresh-encryption-key`
- `nakama-runtime-http-key`
- `nakama-console-password`
- `tpx-platform-internal-key`
- `tpx-magic-link-notify-secret`

Set `nakama-db-address` to a connection that targets the shared platform Postgres instance. Use database `colorcrunch` (or your per-game DB name) on that shared instance.

## 3) Render and apply the service spec

```bash
SERVICE_ACCOUNT_EMAIL="<cloud-run-service-account>"
CLOUDRUN_SERVICE="colorcrunch-nakama"
CLOUDSQL_INSTANCE_CONNECTION_NAME="<project>:<region>:<instance>"
TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL="https://terapixel.games/api/v1/auth/nakama"
TPX_PLATFORM_USERNAME_VALIDATE_URL="https://terapixel.games/api/v1/identity/internal/username/validate"
TPX_PLATFORM_TELEMETRY_EVENTS_URL="https://terapixel.games/api/v1/telemetry/events"

sed \
  -e "s|__CLOUDRUN_SERVICE__|${CLOUDRUN_SERVICE}|g" \
  -e "s|__SERVICE_ACCOUNT_EMAIL__|${SERVICE_ACCOUNT_EMAIL}|g" \
  -e "s|__IMAGE_URI__|${IMAGE_URI}|g" \
  -e "s|__CLOUDSQL_INSTANCES__|${CLOUDSQL_INSTANCE_CONNECTION_NAME}|g" \
  -e "s|__TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL__|${TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL}|g" \
  -e "s|__TPX_PLATFORM_USERNAME_VALIDATE_URL__|${TPX_PLATFORM_USERNAME_VALIDATE_URL}|g" \
  -e "s|__TPX_PLATFORM_TELEMETRY_EVENTS_URL__|${TPX_PLATFORM_TELEMETRY_EVENTS_URL}|g" \
  backend/nakama/cloudrun/service.template.yaml > /tmp/colorcrunch-nakama-service.yaml

gcloud run services replace /tmp/colorcrunch-nakama-service.yaml \
  --project "${PROJECT_ID}" \
  --region "us-central1"
```

`backend/nakama/render/start.sh` is shared for Render and Cloud Run. It accepts database config via `DB_ADDRESS` (preferred), `DATABASE_URL`, or `DB_*` parts.
