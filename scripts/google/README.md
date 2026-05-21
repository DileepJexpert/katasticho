# Google Deployment Scripts

These scripts reduce the Google Cloud VM deployment to a few repeatable commands.

Defaults match the first beta deployment:

```text
Project:  project-e70d88f7-8342-43d8-a26
Zone:     asia-south1-a
Region:   asia-south1
VM:       katixo-beta-1
Static IP: katixo-static-ip
Domains:  app.katixo.com, api.katixo.com
```

Override any default with environment variables.

## Create VM

Run from Google Cloud Shell:

```bash
bash scripts/google/create-vm.sh
```

This creates/reuses:

- reserved static IP
- Compute Engine VM
- 35 GB Ubuntu boot disk

## Provision VM

SSH into the VM:

```bash
gcloud compute ssh katixo-beta-1 \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a
```

Then run:

```bash
bash /opt/katasticho/app/scripts/google/provision-vm.sh
```

If the repo is not cloned yet, you can copy/paste the provision script from GitHub or clone first with your GitHub token.

The provision script installs Docker/Caddy, clones or updates the repo, creates `.env` if missing, starts backend containers, and configures Caddy.

## Deploy Backend Update

Run on the VM:

```bash
bash /opt/katasticho/app/scripts/google/deploy-backend.sh
```

## Deploy Flutter Web Zip

Build Flutter locally:

```powershell
cd C:\dileepkm\Learning\erp-system\katasticho\flutter_app
flutter build web --release `
  --dart-define=ENV=prod `
  --dart-define=API_BASE_URL=https://api.katixo.com
Compress-Archive -Path .\build\web\* -DestinationPath .\flutter-web.zip -Force
```

Upload `flutter-web.zip` to Cloud Shell, then:

```bash
gcloud compute scp ~/flutter-web.zip katixo-beta-1:/tmp/flutter-web.zip \
  --project=project-e70d88f7-8342-43d8-a26 \
  --zone=asia-south1-a
```

Run on VM:

```bash
bash /opt/katasticho/app/scripts/google/deploy-flutter-zip.sh
```

## Health Check

Run on VM:

```bash
bash /opt/katasticho/app/scripts/google/health-check.sh
```

## Destroy VM

Run from Cloud Shell:

```bash
bash scripts/google/destroy-vm.sh
```

It asks you to type `DELETE` before deleting the VM. By default it also deletes the reserved static IP.

To keep static IP:

```bash
DELETE_ADDRESS=false bash scripts/google/destroy-vm.sh
```

