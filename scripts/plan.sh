#!/bin/bash
set -e

ENVIRONMENT=${1:-prod}

echo "=== Terraform Plan - $ENVIRONMENT ==="
echo "Current directory: $(pwd)"

cd environments/$ENVIRONMENT

echo ""
echo "Initializing Terraform..."
terraform init

echo ""
echo "Running Terraform plan..."
terraform plan -out=tfplan

echo ""
echo "Plan saved to: tfplan"
echo "To apply: ./plan.sh $ENVIRONMENT && terraform apply tfplan"
