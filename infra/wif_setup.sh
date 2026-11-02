#!/usr/bin/env bash
# -----------------------------------------------------------------------
# Workload Identity Federation: keyless auth from GitHub Actions to GCP
#
# One-off setup. Run from the repo root:
#   bash infra/wif_setup.sh
#
# Safe to re-run: create steps skip resources that already exist;
# 'services enable' and IAM bindings are idempotent by design.
# -----------------------------------------------------------------------
set -euo pipefail

# --- Config -------------------------------------------------------------
# Load GCP_PROJECT_ID (and anything else) from .env, if present
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

PROJECT_ID="${GCP_PROJECT_ID:?GCP_PROJECT_ID not set (check .env)}"
GITHUB_REPO="diegoscpereira/eur-exchange-rates"
POOL_ID="github"
PROVIDER_ID="github-repo"
SA_NAME="github-ci"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Least privilege for CI: read dataset/table metadata + run query jobs
SA_ROLES=(
  "roles/bigquery.metadataViewer"
  "roles/bigquery.jobUser"
)

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" \
  --format='value(projectNumber)')"

echo "Project: $PROJECT_ID ($PROJECT_NUMBER) | Repo: $GITHUB_REPO"

# --- 1. Enable APIs (idempotent) ----------------------------------------
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  --project="$PROJECT_ID"

# --- 2. Workload Identity Pool ------------------------------------------
if gcloud iam workload-identity-pools describe "$POOL_ID" \
  --project="$PROJECT_ID" --location=global >/dev/null 2>&1; then
  echo "Pool '$POOL_ID' exists, skipping"
else
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$PROJECT_ID" \
    --location=global \
    --display-name="GitHub Actions"
fi

# --- 3. OIDC provider (trust GitHub tokens from this repo only) ---------
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location=global \
  --workload-identity-pool="$POOL_ID" >/dev/null 2>&1; then
  echo "Provider '$PROVIDER_ID' exists, skipping"
else
  gcloud iam workload-identity-pools providers create-oidc \
    "$PROVIDER_ID" \
    --project="$PROJECT_ID" \
    --location=global \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub repo" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,\
attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'"
fi

# --- 4a. Service account for CI -----------------------------------------
if gcloud iam service-accounts describe "$SA_EMAIL" \
  --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Service account '$SA_EMAIL' exists, skipping"
else
  gcloud iam service-accounts create "$SA_NAME" \
    --project="$PROJECT_ID" \
    --display-name="GitHub Actions CI"
fi

# --- 4b. Project roles for the SA (idempotent) --------------------------
for ROLE in "${SA_ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE" \
    --condition=None \
    --quiet >/dev/null
  echo "Granted $ROLE to $SA_EMAIL"
done

# --- 5. Let workflows from this repo impersonate the SA (idempotent) ----
PRINCIPAL="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}\
/locations/global/workloadIdentityPools/${POOL_ID}\
/attribute.repository/${GITHUB_REPO}"

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="$PRINCIPAL" \
  --quiet >/dev/null
echo "Granted workloadIdentityUser on $SA_EMAIL to $GITHUB_REPO"

# --- Output: values the workflow will need ------------------------------
echo
echo "workload_identity_provider:"
gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT_ID" \
  --location=global \
  --workload-identity-pool="$POOL_ID" \
  --format='value(name)'
echo "service_account:"
echo "$SA_EMAIL"