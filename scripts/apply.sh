#!/bin/bash
set -e

ENVIRONMENT=${1:-prod}

echo "=== Terraform Apply - $ENVIRONMENT ==="

if [ ! -f "environments/$ENVIRONMENT/tfplan" ]; then
  echo "Error: tfplan not found. Run ./scripts/plan.sh first"
  exit 1
fi

cd environments/$ENVIRONMENT

echo "Applying Terraform changes..."
terraform apply tfplan

echo ""
echo "=== Deployment Complete ==="
echo ""
terraform output -json | jq .
