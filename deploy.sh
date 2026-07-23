#!/bin/bash
set -e

# SSH private key path (defaults to ~/.ssh/labsuser.pem, or first argument)
KEY_PATH=${1:-"$HOME/.ssh/labsuser.pem"}

# Target Terraform directory (defaults to 'terraform', fallback to 'terraform-study')
TF_DIR="terraform"
if [ ! -d "$(dirname "$0")/$TF_DIR" ]; then
    TF_DIR="terraform-study"
fi

# Retrieve EC2 Public IP from Terraform output
echo "Retrieving EC2 Public IP from Terraform ($TF_DIR)..."
cd "$(dirname "$0")/$TF_DIR"

# Allow overriding AWS_PROFILE, default to morijyobi-2026-devops if not set
DEPLOY_AWS_PROFILE=${AWS_PROFILE-"morijyobi-2026-devops"}

if [ -z "$DEPLOY_AWS_PROFILE" ]; then
    EC2_IP=$(error_msg=$(terraform output -raw public_ip 2>&1) && echo "$error_msg" || echo "")
else
    EC2_IP=$(export AWS_PROFILE="$DEPLOY_AWS_PROFILE" && error_msg=$(terraform output -raw public_ip 2>&1) && echo "$error_msg" || echo "")
fi
cd - > /dev/null



if [[ "$EC2_IP" == *"Error"* ]] || [ -z "$EC2_IP" ]; then
    echo "Error: Could not retrieve EC2 Public IP from Terraform output."
    echo "Make sure your AWS credentials are valid and 'terraform apply' was run successfully."
    echo "Detail: $EC2_IP"
    exit 1
fi

echo "Target EC2 IP: $EC2_IP"

# Check if private key exists
if [ ! -f "$KEY_PATH" ]; then
    echo "--------------------------------------------------------"
    echo "Warning: Private key not found at default path ($KEY_PATH)"
    echo "Please specify the correct path to your .pem file."
    echo "Usage: ./deploy.sh [path/to/private-key.pem]"
    echo "--------------------------------------------------------"
    # Prompt the user for the key path if running interactively, or wait for input
    read -p "Enter path to your private key (.pem file): " KEY_PATH
    if [ ! -f "$KEY_PATH" ]; then
        echo "Error: Private key file still not found. Aborting."
        exit 1
    fi
fi

# Ensure correct permissions on the private key
chmod 400 "$KEY_PATH"

echo "Connecting to EC2 and preparing directory..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$EC2_IP" "mkdir -p ~/app"

echo "Syncing project files to EC2 via rsync..."
rsync -avz -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
    --exclude="node_modules" \
    --exclude="*/node_modules" \
    --exclude=".git" \
    --exclude=".next" \
    --exclude=".open-next" \
    --exclude=".wrangler" \
    --exclude="terraform-study/.terraform" \
    --exclude="terraform-study/*.tfstate*" \
    ./ ubuntu@"$EC2_IP":~/app/

echo "Starting Docker containers on EC2..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$EC2_IP" "cd ~/app && docker compose -f compose.prod.yaml down && docker compose -f compose.prod.yaml up -d --build"

echo "=========================================================="
echo " Deployment successful!"
echo " Access your production application at:"
echo " http://$EC2_IP"
echo "=========================================================="
