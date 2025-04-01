#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print step headers
print_step() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

# Function to check if command was successful
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 completed successfully${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Check if environment argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide environment (dev, staging, or prod)${NC}"
    echo "Usage: ./deploy.sh <environment>"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment. Must be dev, staging, or prod${NC}"
    exit 1
fi

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    source ".env.$ENVIRONMENT"
else
    echo -e "${RED}Error: .env.$ENVIRONMENT file not found${NC}"
    exit 1
fi

# Frontend Build
print_step "Building Frontend (Flutter Web)"
cd frontend
flutter clean
check_success "Flutter clean"

flutter pub get
check_success "Flutter dependencies installation"

flutter build web --release
check_success "Flutter web build"

# Backend Build
print_step "Building Backend (TypeScript)"
cd ../backend
npm ci
check_success "NPM dependencies installation"

npm run build
check_success "TypeScript build"

# Create Lambda deployment packages
print_step "Creating Lambda Deployment Packages"
cd dist/lambda
for lambda in *.js; do
    zip -r "${lambda%.js}.zip" "$lambda"
    check_success "Creating zip for $lambda"
done
cd ../..

# Terraform Deployment
print_step "Deploying Infrastructure with Terraform"
cd ../infrastructure/terraform

# Copy appropriate tfvars file
if [ -f "terraform.tfvars.$ENVIRONMENT" ]; then
    cp "terraform.tfvars.$ENVIRONMENT" terraform.tfvars
    check_success "Copying terraform.tfvars.$ENVIRONMENT"
fi

# Initialize Terraform
terraform init
check_success "Terraform init"

# Plan the changes
terraform plan -out=tfplan
check_success "Terraform plan"

# Apply the changes
echo -e "${YELLOW}Do you want to apply these changes? (yes/no)${NC}"
read -r APPLY_CHANGES

if [ "$APPLY_CHANGES" = "yes" ]; then
    terraform apply tfplan
    check_success "Terraform apply"
else
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Upload frontend build to S3
print_step "Uploading Frontend to S3"
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)
aws s3 sync ../../frontend/build/web "s3://$FRONTEND_BUCKET" --delete
check_success "Frontend S3 upload"

# Invalidate CloudFront cache
print_step "Invalidating CloudFront Cache"
CLOUDFRONT_DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DIST_ID" --paths "/*"
check_success "CloudFront cache invalidation"

# Print deployment information
print_step "Deployment Information"
echo -e "${GREEN}Frontend URL:${NC} $(terraform output -raw cloudfront_domain_name)"
echo -e "${GREEN}API Gateway URL:${NC} $(terraform output -raw api_gateway_url)"
echo -e "${GREEN}Environment:${NC} $ENVIRONMENT"

print_step "Deployment Complete!"
echo -e "${GREEN}The application has been successfully deployed to $ENVIRONMENT environment${NC}"