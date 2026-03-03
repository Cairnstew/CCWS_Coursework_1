#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# CONFIGURATION VARIABLES
# ------------------------------
PROJECT_ID="${1:-ccws-coursework-1}"   # pass as first argument or default
NETWORK="${2:-vpc-nixos}"              # network name
SUBNET="${3:-subnet-sg}"               # subnet name
REGION="${4:-europe-west2}"            # region

# ------------------------------
# DELETE DEFAULT NETWORK RULES (optional)
# ------------------------------
echo "Deleting firewall rules on default network..."
for rule in $(gcloud compute firewall-rules list --filter="network=default" --format="value(name)"); do
    gcloud compute firewall-rules delete "$rule" --quiet || true
done

# Delete default network if unused
if gcloud compute networks describe default &>/dev/null; then
    if ! gcloud compute instances list --filter="networkInterfaces.network:default" --format="value(name)" | grep .; then
        gcloud compute networks delete default --quiet || true
        echo "Deleted default network."
    else
        echo "Default network still has attached VMs; skipping deletion."
    fi
fi

# ------------------------------
# CREATE CUSTOM NETWORK
# ------------------------------
if ! gcloud compute networks describe "${NETWORK}" &>/dev/null; then
    gcloud compute networks create "${NETWORK}" --subnet-mode=custom --quiet
    echo "Created network: ${NETWORK}"
else
    echo "Network ${NETWORK} already exists; skipping creation."
fi

# ------------------------------
# CREATE SUBNET
# ------------------------------
if ! gcloud compute networks subnets describe "${SUBNET}" --region="${REGION}" &>/dev/null; then
    gcloud compute networks subnets create "${SUBNET}" \
        --network="${NETWORK}" \
        --range=192.168.1.0/24 \
        --region="${REGION}" \
        --quiet
    echo "Created subnet: ${SUBNET} in region ${REGION}"
else
    echo "Subnet ${SUBNET} already exists; skipping creation."
fi

# ------------------------------
# CREATE FIREWALL RULES
# ------------------------------
declare -A FW_RULES=(
    [allow-ssh]="tcp:22"
    [allow-web-traffic]="tcp:80,tcp:443"
    [allow-iap-ssh]="tcp:22"
)

for RULE in "${!FW_RULES[@]}"; do
    if ! gcloud compute firewall-rules describe "$RULE" &>/dev/null; then
        gcloud compute firewall-rules create "$RULE" \
            --direction=INGRESS \
            --priority=1000 \
            --network="${NETWORK}" \
            --action=ALLOW \
            --rules="${FW_RULES[$RULE]}" \
            --target-tags="$RULE" \
            --quiet
        echo "Created firewall rule: $RULE"
    else
        echo "Firewall rule $RULE already exists; skipping."
    fi
done

echo "Network configuration complete."