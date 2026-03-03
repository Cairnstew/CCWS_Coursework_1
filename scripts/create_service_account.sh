#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT=${PROJECT:-}
BUCKET=${BUCKET:-}
GITHUB_REPO="${YOUR_GITHUB_ORG}/${YOUR_REPO}"
SERVICE_ACCOUNT="github-actions"
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"
# ─────────────────────────────────────────────────────────────────────────────

SA_EMAIL="${SERVICE_ACCOUNT}@${PROJECT}.iam.gserviceaccount.com"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format="value(projectNumber)")

echo "==> Project:        $PROJECT"
echo "==> Project number: $PROJECT_NUMBER"
echo "==> Service account: $SA_EMAIL"
echo "==> GitHub repo:    $GITHUB_REPO"
echo ""

# ── 1. Service account ────────────────────────────────────────────────────────
echo "==> [1/6] Creating service account..."
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" &>/dev/null; then
  echo "    Already exists, skipping."
else
  gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
    --display-name="GitHub Actions" \
    --project="$PROJECT"
fi

# ── 2. IAM roles ──────────────────────────────────────────────────────────────
echo "==> [2/6] Granting IAM roles..."
for ROLE in roles/compute.admin roles/storage.admin roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$ROLE" \
    --condition=None \
    --quiet
  echo "    Granted $ROLE"
done

# ── 3. Workload identity pool ─────────────────────────────────────────────────
echo "==> [3/6] Creating workload identity pool..."
if gcloud iam workload-identity-pools describe "$POOL_NAME" \
     --location="global" --project="$PROJECT" &>/dev/null; then
  echo "    Already exists, skipping."
else
  gcloud iam workload-identity-pools create "$POOL_NAME" \
    --location="global" \
    --display-name="GitHub Actions Pool" \
    --project="$PROJECT"
fi

# ── 4. OIDC provider ──────────────────────────────────────────────────────────
echo "==> [4/6] Creating OIDC provider..."
if gcloud iam workload-identity-pools providers describe "$PROVIDER_NAME" \
     --location="global" \
     --workload-identity-pool="$POOL_NAME" \
     --project="$PROJECT" &>/dev/null; then
  echo "    Already exists, skipping."
else
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
    --location="global" \
    --workload-identity-pool="$POOL_NAME" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'" \
    --project="$PROJECT"
fi

# ── 5. Bind SA to pool ────────────────────────────────────────────────────────
echo "==> [5/6] Binding service account to workload identity pool..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO}" \
  --project="$PROJECT"

# ── 6. Print GitHub secrets ───────────────────────────────────────────────────
echo ""
echo "==> [6/6] Done! Add these to GitHub → Settings → Secrets → Actions:"
echo ""

PROVIDER_RESOURCE=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_NAME" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --project="$PROJECT" \
  --format="value(name)")

echo "  GCP_PROJECT:                    $PROJECT"
echo "  GCP_SERVICE_ACCOUNT:            $SA_EMAIL"
echo "  GCP_WORKLOAD_IDENTITY_PROVIDER: $PROVIDER_RESOURCE"
echo "  GCP_BUCKET:                     $BUCKET"
echo ""
echo "==> All done."
