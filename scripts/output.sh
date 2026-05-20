#!/bin/bash
set -e

ENVIRONMENT=${1:-prod}

echo "=== Terraform Outputs - $ENVIRONMENT ==="
cd environments/$ENVIRONMENT
terraform output -json | jq .
