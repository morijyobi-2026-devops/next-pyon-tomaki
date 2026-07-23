#!/bin/bash
set -e

# SSH private key path (defaults to ~/.ssh/labsuser.pem, or first argument)
KEY_PATH=${1:-"$HOME/.ssh/labsuser.pem"}

# Target Terraform directory (defaults to 'terraform', fallback to 'terraform-study')
TF_DIR="terraform"
if [ ! -d "$(dirname "$0")/$TF_DIR" ]; then
    TF_DIR="terraform-study"
fi

# Allow overriding AWS_PROFILE, default to morijyobi-2026-devops if not set
DEPLOY_AWS_PROFILE=${AWS_PROFILE-"morijyobi-2026-devops"}

echo "Retrieving outputs from Terraform ($TF_DIR)..."
cd "$(dirname "$0")/$TF_DIR"

if [ -z "$DEPLOY_AWS_PROFILE" ]; then
    EC2_IP=$(error_msg=$(terraform output -raw public_ip 2>&1) && echo "$error_msg" || echo "")
    S3_BUCKET=$(error_msg=$(terraform output -raw s3_bucket_name 2>&1) && echo "$error_msg" || echo "")
else
    EC2_IP=$(export AWS_PROFILE="$DEPLOY_AWS_PROFILE" && error_msg=$(terraform output -raw public_ip 2>&1) && echo "$error_msg" || echo "")
    S3_BUCKET=$(export AWS_PROFILE="$DEPLOY_AWS_PROFILE" && error_msg=$(terraform output -raw s3_bucket_name 2>&1) && echo "$error_msg" || echo "")
fi
cd - > /dev/null

if [[ "$EC2_IP" == *"Error"* ]] || [ -z "$EC2_IP" ]; then
    echo "Error: Could not retrieve EC2 Public IP from Terraform output."
    echo "Make sure your AWS credentials are valid and 'terraform apply' was run successfully."
    echo "Detail: $EC2_IP"
    exit 1
fi

if [[ "$S3_BUCKET" == *"Error"* ]] || [ -z "$S3_BUCKET" ]; then
    echo "Error: Could not retrieve S3 Bucket Name from Terraform output."
    echo "Detail: $S3_BUCKET"
    exit 1
fi

echo "Target EC2 IP: $EC2_IP"
echo "Target S3 Bucket: $S3_BUCKET"

# Check if private key exists
if [ ! -f "$KEY_PATH" ]; then
    echo "--------------------------------------------------------"
    echo "Warning: Private key not found at default path ($KEY_PATH)"
    echo "Please specify the correct path to your .pem file."
    echo "Usage: ./deploy.sh [path/to/private-key.pem]"
    echo "--------------------------------------------------------"
    read -p "Enter path to your private key (.pem file): " KEY_PATH
    if [ ! -f "$KEY_PATH" ]; then
        echo "Error: Private key file still not found. Aborting."
        exit 1
    fi
fi

# Ensure correct permissions on the private key
chmod 400 "$KEY_PATH"

# 1. Zip local source code
echo "Compressing local source code into deploy.zip..."
if [ -f deploy.zip ]; then
    rm deploy.zip
fi

# Check if zip command is installed
if ! command -v zip &> /dev/null; then
    echo "Error: 'zip' command is required on the local machine."
    echo "Please install it (e.g., 'sudo apt install zip' or 'brew install zip')."
    exit 1
fi

zip -r deploy.zip . \
    -x "node_modules/*" \
    -x "*/node_modules/*" \
    -x ".git/*" \
    -x ".next/*" \
    -x ".open-next/*" \
    -x ".wrangler/*" \
    -x "terraform/.terraform/*" \
    -x "terraform/*.tfstate*" \
    -x "deploy.zip" \
    > /dev/null

# 2. Upload zip to S3
echo "Uploading deploy.zip to Amazon S3..."
if [ -z "$DEPLOY_AWS_PROFILE" ]; then
    aws s3 cp deploy.zip "s3://$S3_BUCKET/deploy.zip"
else
    aws s3 cp deploy.zip "s3://$S3_BUCKET/deploy.zip" --profile "$DEPLOY_AWS_PROFILE"
fi

# Clean up local zip
rm deploy.zip

# 3. SSH to EC2, download from S3, extract and start Docker
echo "Connecting to EC2 and starting application..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$EC2_IP" \
    "mkdir -p ~/app && \
     aws s3 cp s3://$S3_BUCKET/deploy.zip ~/app/deploy.zip && \
     unzip -o ~/app/deploy.zip -d ~/app/ && \
     rm ~/app/deploy.zip && \
     cd ~/app && \
     docker compose -f compose.prod.yaml down && \
     docker compose -f compose.prod.yaml up -d --build"

echo "=========================================================="
echo " Deployment successful!"
echo " Access your production application at:"
echo " http://$EC2_IP"
echo "=========================================================="
