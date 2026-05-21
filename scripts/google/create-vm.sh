#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-project-e70d88f7-8342-43d8-a26}"
ZONE="${ZONE:-asia-south1-a}"
REGION="${REGION:-asia-south1}"
INSTANCE_NAME="${INSTANCE_NAME:-katixo-beta-1}"
ADDRESS_NAME="${ADDRESS_NAME:-katixo-static-ip}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"
DISK_SIZE_GB="${DISK_SIZE_GB:-35}"

echo "Using project: $PROJECT_ID"
echo "Using zone:    $ZONE"

if ! gcloud compute addresses describe "$ADDRESS_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" >/dev/null 2>&1; then
  echo "Creating static IP: $ADDRESS_NAME"
  gcloud compute addresses create "$ADDRESS_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION"
fi

STATIC_IP="$(gcloud compute addresses describe "$ADDRESS_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format='value(address)')"

if gcloud compute instances describe "$INSTANCE_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" >/dev/null 2>&1; then
  echo "Instance already exists: $INSTANCE_NAME"
else
  echo "Creating instance: $INSTANCE_NAME ($MACHINE_TYPE, ${DISK_SIZE_GB}GB, $STATIC_IP)"
  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface="address=$STATIC_IP,network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default" \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
    --tags=http-server,https-server \
    --create-disk="auto-delete=yes,boot=yes,device-name=$INSTANCE_NAME,image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts-amd64,mode=rw,size=$DISK_SIZE_GB,type=pd-balanced" \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any
fi

echo
echo "Instance status:"
gcloud compute instances list \
  --project="$PROJECT_ID" \
  --filter="name=$INSTANCE_NAME"

echo
echo "Next:"
echo "  gcloud compute ssh $INSTANCE_NAME --project=$PROJECT_ID --zone=$ZONE"
echo "  bash /opt/katasticho/app/scripts/google/provision-vm.sh"
