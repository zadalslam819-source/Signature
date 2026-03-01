#!/bin/bash
set -e

# Keycast Litestream Deployment Script
# This script sets up Litestream + Cloud Run for persistent SQLite

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
SERVICE_NAME="keycast-oauth"
BUCKET_NAME="keycast-database-backups"
IMAGE_URL="us-central1-docker.pkg.dev/${PROJECT_ID}/docker/keycast:latest"

echo "================================================"
echo "🔑 Keycast Litestream Deployment"
echo "================================================"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Service: $SERVICE_NAME"
echo "Bucket: $BUCKET_NAME"
echo ""

# Step 1: Create GCS bucket for Litestream backups
echo "📦 Creating GCS bucket for database backups..."
if gsutil ls gs://$BUCKET_NAME 2>/dev/null; then
    echo "✅ Bucket gs://$BUCKET_NAME already exists"
else
    gsutil mb -l $REGION gs://$BUCKET_NAME/
    echo "✅ Created bucket gs://$BUCKET_NAME"
fi

# Step 2: Get Cloud Run service account
echo ""
echo "🔐 Configuring service account permissions..."
SERVICE_ACCOUNT="${PROJECT_ID}@appspot.gserviceaccount.com"
echo "Service Account: $SERVICE_ACCOUNT"

# Grant bucket access to service account
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT:roles/storage.objectAdmin gs://$BUCKET_NAME
echo "✅ Granted storage.objectAdmin to service account"

# Grant Secret Manager access for all required secrets
echo ""
echo "🔐 Granting Secret Manager access to service account..."
for SECRET in keycast-gcp-project keycast-jwt-secret keycast-sendgrid-api-key keycast-master-key litestream-config; do
    if gcloud secrets describe $SECRET --project=$PROJECT_ID 2>/dev/null; then
        gcloud secrets add-iam-policy-binding $SECRET \
            --member="serviceAccount:$SERVICE_ACCOUNT" \
            --role="roles/secretmanager.secretAccessor" \
            --project=$PROJECT_ID >/dev/null 2>&1 || true
        echo "  ✅ $SECRET"
    else
        echo "  ⚠️  $SECRET (secret doesn't exist yet - will be created separately)"
    fi
done
echo "✅ Secret Manager permissions granted"

# Step 3: Create or update litestream-config in Secret Manager
echo ""
echo "🔒 Creating Litestream configuration in Secret Manager..."
if gcloud secrets describe litestream-config --project=$PROJECT_ID 2>/dev/null; then
    echo "Secret already exists in Secret Manager, creating new version..."
    gcloud secrets versions add litestream-config \
        --data-file=litestream.yml \
        --project=$PROJECT_ID
else
    gcloud secrets create litestream-config \
        --data-file=litestream.yml \
        --project=$PROJECT_ID
fi
echo "✅ Litestream config stored in Secret Manager"

# Step 4: Update service.yaml with actual values
echo ""
echo "📝 Preparing service configuration..."
sed -e "s|IMAGE_URL|$IMAGE_URL|g" \
    -e "s|PROJECT_ID@appspot.gserviceaccount.com|$SERVICE_ACCOUNT|g" \
    service.yaml > service-deploy.yaml
echo "✅ Service config prepared"

# Step 5: Deploy to Cloud Run
echo ""
echo "🚀 Deploying to Cloud Run..."
gcloud run services replace service-deploy.yaml \
    --region=$REGION \
    --project=$PROJECT_ID

# Step 6: Update service constraints (single instance for SQLite)
echo ""
echo "⚙️  Configuring scaling limits..."
echo "Note: min-instances=1 keeps warm instance (faster cold starts, continuous replication)"
echo "      This slightly increases baseline cost but ensures data persistence."
gcloud run services update $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --max-instances=1 \
    --min-instances=1 \
    --cpu=2 \
    --memory=2Gi

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""
echo "Service URL: https://$SERVICE_NAME-$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)' | cut -d'/' -f3 | cut -d'-' -f2-)"
echo ""
echo "📊 Check deployment status:"
echo "  gcloud run services describe $SERVICE_NAME --region=$REGION"
echo ""
echo "📝 View logs:"
echo "  gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
echo ""
echo "🗄️ Verify database backups:"
echo "  gsutil ls gs://$BUCKET_NAME/keycast.db/"
echo ""
echo "================================================"
