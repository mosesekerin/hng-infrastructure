#!/bin/bash
set -e

ENVIRONMENT=${1:-prod}

echo "⚠️  WARNING: This will DESTROY all infrastructure in $ENVIRONMENT"
read -p "Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cancelled."
  exit 1
fi

cd environments/$ENVIRONMENT

echo "Destroying infrastructure..."
terraform destroy

echo ""
echo "=== Infrastructure Destroyed ==="
