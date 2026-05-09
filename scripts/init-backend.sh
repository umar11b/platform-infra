#!/usr/bin/env bash
# Run once before `terraform init` to create the GCS state bucket.
# Requires: gcloud auth application-default login (run on the Pi)
set -euo pipefail

PROJECT_ID="gke-infrastructure-493002"
BUCKET="gke-infrastructure-493002-tfstate"
REGION="us-central1"

echo "Enabling cloudresourcemanager API..."
gcloud services enable cloudresourcemanager.googleapis.com --project "$PROJECT_ID"

echo "Creating GCS state bucket: gs://$BUCKET"
gcloud storage buckets create "gs://$BUCKET" \
  --project "$PROJECT_ID" \
  --location "$REGION" \
  --uniform-bucket-level-access \
  --public-access-prevention

echo "Enabling versioning on state bucket..."
gcloud storage buckets update "gs://$BUCKET" --versioning

echo ""
echo "Done. Now run: terraform init"
echo "Then copy terraform.tfvars.example → terraform.tfvars and fill in your values."
