#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# CONFIGURATION
# -------------------------------
PROJECT_ID="${1:-}"   # pass your project ID as first argument
SA_NAME="${2:-ccws-sa}" # service account name
SA_DISPLAY_NAME="${3:-CCWS Coursework Service Account}"
KEY_FILE="${4:-ccws-key.json}" # output key file
ROLE="${5:-roles/editor}" # default role, can adjust

# -------------------------------
# CHECKS
# -------------------------------
if [[ -z "$PROJECT_ID" ]]; then
    echo "Usage: $0 PROJECT_ID [SA_NAME] [SA_DISPLAY_NAME] [KEY_FILE] [ROLE]"
    exit 1
fi

echo "Using project: $PROJECT_ID"
echo "Service account name: $SA_NAME"
echo "Display name: $SA_DISPLAY_NAME"
echo "Key file: $KEY_FILE"
echo "Role: $ROLE"

# Ensure gcloud is logged in
if ! gcloud auth list --format="value(account)" | grep -q '.'; then
    echo "You must be logged in with a Google account first."
    exit 1
fi

# -------------------------------
# CREATE SERVICE ACCOUNT
# -------------------------------
echo "Creating service account..."
gcloud iam service-accounts create "$SA_NAME" \
    --project "$PROJECT_ID" \
    --display-name "$SA_DISPLAY_NAME" || true

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Service account created: $SA_EMAIL"

# -------------------------------
# GRANT ROLE
# -------------------------------
echo "Granting role $ROLE to $SA_EMAIL..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$ROLE"

# -------------------------------
# CREATE KEY
# -------------------------------
echo "Creating key file..."
gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account "$SA_EMAIL"

chmod 600 "$KEY_FILE"
echo "Key saved to $KEY_FILE"
export GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE"

# -------------------------------
# DONE
# -------------------------------
echo "Service account $SA_EMAIL ready with key $KEY_FILE"
echo "Activate with: gcloud auth activate-service-account --key-file=$KEY_FILE"