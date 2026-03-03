#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# CONFIGURATION
# ------------------------------
PROJECT_ID="${1:-ccws-coursework-1}"
IMAGE_DIR="${2:-./result}"
IMAGE_NAME="${3:-nixos-image-google-compute}"
REGION="${4:-europe-west2}"
IMAGE_FAMILY="${5:-nixos-family}"
BUCKET="gs://${PROJECT_ID}-images"          # GCS bucket name

# ------------------------------
# FIND THE .raw.tar.gz FILE
# ------------------------------
TAR_FILE=$(find "$IMAGE_DIR" -maxdepth 1 -name "*.raw.tar.gz" -print -quit)

if [ -z "$TAR_FILE" ]; then
    echo "❌ No .raw.tar.gz found in $IMAGE_DIR"
    exit 1
fi

VERSION=$(basename "$TAR_FILE" .raw.tar.gz)

# Sanitize to valid GCP image name (a-z, 0-9, - only, max 63 chars)
CLEAN_NAME=$(echo "$VERSION" | tr '._' '-' | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9-]//g' \
    | sed 's/--*/-/g' \
    | sed 's/nixos-image-google-compute-//' \
    | cut -c1-63 \
    | sed 's/^-//;s/-$//')

echo "✅ Found image: $TAR_FILE"
echo "✅ GCP-safe name: $CLEAN_NAME"

# ------------------------------
# CREATE BUCKET IF NEEDED
# ------------------------------
if ! gcloud storage buckets describe "$BUCKET" &>/dev/null; then
    echo "Creating bucket: $BUCKET..."
    gcloud storage buckets create "$BUCKET" \
        --project="$PROJECT_ID" \
        --location="$REGION" \
        --uniform-bucket-level-access \
        --quiet
    echo "✅ Bucket created."
else
    echo "✅ Bucket $BUCKET already exists; skipping creation."
fi

# ------------------------------
# UPLOAD IMAGE IF NOT ALREADY PRESENT
# ------------------------------
if gcloud storage ls "$BUCKET/$VERSION.raw.tar.gz" &>/dev/null; then
    echo "✅ $VERSION.raw.tar.gz already exists in GCS; skipping upload."
else
    echo "⬆️ Uploading $TAR_FILE to $BUCKET/$VERSION.raw.tar.gz..."
    gcloud storage cp "$TAR_FILE" "$BUCKET/$VERSION.raw.tar.gz"
    echo "✅ Upload complete."
fi

GCP_IMAGE_NAME="nixos-$(echo "$CLEAN_NAME" | cut -c1-56)"

# Create image
if gcloud compute images describe "$GCP_IMAGE_NAME" --project=${PROJECT_ID} &>/dev/null; then
  echo "✅ GCP image already exists"
else
  echo "Creating GCP image..."
  gcloud compute images create "$GCP_IMAGE_NAME" \
    --project="${PROJECT_ID}" \
    --source-uri="$BUCKET/$VERSION.raw.tar.gz" \
    --family="${IMAGE_FAMILY}" \
    --guest-os-features=VIRTIO_SCSI_MULTIQUEUE
fi

echo "Image file:  $VERSION"
echo "GCP image:   $GCP_IMAGE_NAME"
echo "Bucket obj:  $BUCKET/$VERSION.raw.tar.gz"
