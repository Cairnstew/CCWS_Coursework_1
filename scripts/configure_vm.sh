#!/usr/bin/env bash
set -euo pipefail

PROJECT="ccws-coursework-1"
REGION="europe-west2"
ZONE="$REGION-a"
VM_NAME="nixos-vm"
NETWORK="vpc-nixos"

gcloud compute firewall-rules delete default-allow-internal -- quiet || true
gcloud compute firewall-rules delete default-allow-rdp -- quiet || true
gcloud compute firewall-rules delete default-allow-ssh -- quiet || true
gcloud compute firewall-rules delete default-allow-icmp -- quiet || true
gcloud compute networks delete default --quiet || true

gcloud compute networks create $NETWORK --subnet-mode=custom

gcloud compute networks subnets create subnet-sg --network=$NETWORK --range=192.168.1.0/24 --region $REGION

gcloud compute --project=$PROJECT firewall-rules create allow-ssh --direction=INGRESS --priority=1000 --network=$NETWORK --action=ALLOW --rules=tcp:22 --target-tags=allow-ssh
