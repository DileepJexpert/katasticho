#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-project-e70d88f7-8342-43d8-a26}"
ZONE="${ZONE:-asia-south1-a}"
REGION="${REGION:-asia-south1}"
INSTANCE_NAME="${INSTANCE_NAME:-katixo-beta-1}"
ADDRESS_NAME="${ADDRESS_NAME:-katixo-static-ip}"
DELETE_ADDRESS="${DELETE_ADDRESS:-true}"

echo "This deletes the VM. Auto-delete boot disk data will be lost."
read -r -p "Delete instance '$INSTANCE_NAME' in '$ZONE'? Type DELETE to continue: " confirm
if [ "$confirm" != "DELETE" ]; then
  echo "Cancelled."
  exit 0
fi

if gcloud compute instances describe "$INSTANCE_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" >/dev/null 2>&1; then
  gcloud compute instances delete "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --quiet
else
  echo "Instance not found: $INSTANCE_NAME"
fi

if [ "$DELETE_ADDRESS" = "true" ]; then
  if gcloud compute addresses describe "$ADDRESS_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" >/dev/null 2>&1; then
    gcloud compute addresses delete "$ADDRESS_NAME" \
      --project="$PROJECT_ID" \
      --region="$REGION" \
      --quiet
  else
    echo "Static IP not found: $ADDRESS_NAME"
  fi
else
  echo "Keeping static IP because DELETE_ADDRESS=$DELETE_ADDRESS"
fi

echo "Remaining instances:"
gcloud compute instances list --project="$PROJECT_ID"
