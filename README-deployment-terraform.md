I'll create a comprehensive deployment guide for you.

```bash
cd ~/aws_apps/twin

cat > README-Deployment-Terraform.md << 'EOF'
# Twin Application - Terraform Deployment Guide

**Version:** 1.0.0  
**Target Audience:** Solutions Architects, Senior Developers, DevOps Engineers  
**Last Updated:** December 2025

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Project Structure](#project-structure)
4. [Infrastructure Components](#infrastructure-components)
5. [Configuration Guide](#configuration-guide)
6. [Deployment Process](#deployment-process)
7. [Post-Deployment Tasks](#post-deployment-tasks)
8. [Custom Domain Setup](#custom-domain-setup)
9. [Cost Estimation](#cost-estimation)
10. [Security Considerations](#security-considerations)
11. [Monitoring & Operations](#monitoring--operations)
12. [Troubleshooting](#troubleshooting)
13. [Cleanup & Destruction](#cleanup--destruction)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│         CloudFront (CDN)                │
│  - HTTPS/TLS Termination                │
│  - Global Edge Caching                  │
│  - Custom Domain (Optional)             │
└──────┬──────────────────────────────────┘
       │
       ├────────────────┬─────────────────┐
       ▼                ▼                 ▼
┌─────────────┐  ┌──────────────┐  ┌──────────────┐
│ S3 Frontend │  │ API Gateway  │  │              │
│   Bucket    │  │   HTTP API   │  │   Route53    │
│  (Static)   │  └──────┬───────┘  │ (DNS/Custom) │
└─────────────┘         │          └──────────────┘
                        ▼
                 ┌──────────────┐
                 │    Lambda    │
                 │   Function   │
                 │  (Python)    │
                 └──────┬───────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
  ┌────────────┐ ┌────────────┐ ┌────────────┐
  │  Bedrock   │ │ S3 Memory  │ │ CloudWatch │
  │   (AI)     │ │   Bucket   │ │   Logs     │
  └────────────┘ └────────────┘ └────────────┘
```

### Technology Stack

- **Compute:** AWS Lambda (Python 3.12)
- **AI/ML:** Amazon Bedrock (Nova Micro)
- **API:** API Gateway HTTP API
- **Storage:** Amazon S3 (Frontend + Memory)
- **CDN:** CloudFront
- **DNS:** Route53 (Optional)
- **Security:** ACM, IAM
- **IaC:** Terraform 1.10+

---

## Prerequisites

### Required Tools

```bash
# Terraform
terraform --version  # >= 1.0.0 required

# AWS CLI
aws --version        # >= 2.0 required
aws configure list   # Verify credentials

# Python (for backend)
python3 --version    # >= 3.12 required
pip3 --version

# Optional but recommended
jq --version        # JSON processor
```

### AWS Account Requirements

1. **IAM Permissions Required:**
   - S3: Full access (bucket creation, policy management)
   - Lambda: Full access (function creation, role management)
   - API Gateway: Full access (API creation, deployment)
   - CloudFront: Full access (distribution management)
   - Route53: Full access (if using custom domain)
   - ACM: Certificate management (us-east-1 region)
   - IAM: Role and policy creation
   - CloudWatch: Logs access

2. **Service Quotas:**
   - CloudFront distributions: At least 1 available
   - Lambda concurrent executions: 10+ recommended
   - API Gateway APIs: At least 1 available

3. **Bedrock Access:**
   - Ensure Amazon Bedrock is enabled in your region
   - Model access granted for `amazon.nova-micro-v1:0`
   - Check: AWS Console → Bedrock → Model Access

### AWS CLI Configuration

```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity

# Check Bedrock access
aws bedrock list-foundation-models --region us-east-1 \
  --query 'modelSummaries[?modelId==`amazon.nova-micro-v1:0`]'
```

---

## Project Structure

```
twin/
├── backend/
│   ├── lambda_handler.py          # Lambda entry point
│   ├── requirements.txt            # Python dependencies
│   └── lambda-deployment.zip       # Deployment package (generated)
├── frontend/
│   ├── index.html                  # Main HTML
│   ├── styles.css                  # Styling
│   ├── script.js                   # Frontend logic
│   └── 404.html                    # Error page
├── memory/                         # S3 memory storage (created by TF)
└── terraform/
    ├── versions.tf                 # Provider configuration
    ├── variables.tf                # Variable definitions
    ├── terraform.tfvars            # Variable values
    ├── main.tf                     # Infrastructure resources
    └── outputs.tf                  # Output values
```

---

## Infrastructure Components

### 1. S3 Buckets

**Frontend Bucket:**
- Purpose: Static website hosting
- Configuration: Public read access, website hosting enabled
- Content: HTML, CSS, JavaScript files
- Naming: `{project}-{env}-frontend-{account-id}`

**Memory Bucket:**
- Purpose: Conversation state persistence
- Configuration: Private, encrypted at rest
- Access: Lambda function only
- Naming: `{project}-{env}-memory-{account-id}`

### 2. Lambda Function

**Specifications:**
- Runtime: Python 3.12
- Architecture: x86_64
- Timeout: 60 seconds (configurable)
- Memory: 128 MB (default)
- Environment Variables:
  - `CORS_ORIGINS`: CloudFront URL
  - `S3_BUCKET`: Memory bucket name
  - `USE_S3`: "true"
  - `BEDROCK_MODEL_ID`: Model identifier

**IAM Permissions:**
- CloudWatch Logs (write)
- Bedrock (invoke model)
- S3 (read/write to memory bucket)

### 3. API Gateway

**Configuration:**
- Type: HTTP API (not REST)
- CORS: Enabled for all origins
- Throttling: 5 requests/second, burst 10
- Routes:
  - `GET /`: Health check
  - `POST /chat`: Chat endpoint
  - `GET /health`: Health endpoint

### 4. CloudFront Distribution

**Settings:**
- Origin: S3 website endpoint (HTTP)
- Viewer Protocol: Redirect to HTTPS
- Cache Behavior: Standard caching (1 hour default TTL)
- Custom Error Response: 404 → /index.html (SPA routing)
- Price Class: All edge locations (configurable)
- IPv6: Enabled

### 5. Custom Domain (Optional)

**Requirements:**
- Route53 hosted zone for domain
- ACM certificate (us-east-1 region)
- DNS validation

**Configuration:**
- Apex domain: example.com
- WWW subdomain: www.example.com
- Both IPv4 (A) and IPv6 (AAAA) records

---

## Configuration Guide

### Environment Variables (`terraform.tfvars`)

```hcl
# Core Configuration
project_name             = "twin"              # Alphanumeric + hyphens only
environment              = "dev"               # dev, test, or prod

# AI Model Configuration
bedrock_model_id         = "amazon.nova-micro-v1:0"  # Bedrock model ID

# Lambda Configuration
lambda_timeout           = 60                  # Seconds (max: 900)

# API Gateway Throttling
api_throttle_burst_limit = 10                  # Burst capacity
api_throttle_rate_limit  = 5                   # Requests per second

# Custom Domain (Optional)
use_custom_domain        = false               # Set to true to enable
root_domain              = ""                  # e.g., "example.com"
```

### Multi-Environment Setup

**Development:**
```hcl
# terraform/dev.tfvars
project_name             = "twin"
environment              = "dev"
api_throttle_burst_limit = 10
api_throttle_rate_limit  = 5
```

**Production:**
```hcl
# terraform/prod.tfvars
project_name             = "twin"
environment              = "prod"
api_throttle_burst_limit = 100
api_throttle_rate_limit  = 50
lambda_timeout           = 120
use_custom_domain        = true
root_domain              = "yourdomain.com"
```

**Usage:**
```bash
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

---

## Deployment Process

### Step 1: Prepare Backend Lambda Package

```bash
cd ~/aws_apps/twin/backend

# Install dependencies
pip3 install -r requirements.txt -t .

# Create deployment package
zip -r lambda-deployment.zip . \
  -x "*.pyc" \
  -x "__pycache__/*" \
  -x ".pytest_cache/*" \
  -x "tests/*"

# Verify package
unzip -l lambda-deployment.zip | head -20
```

### Step 2: Initialize Terraform

```bash
cd ~/aws_apps/twin/terraform

# Initialize providers and modules
terraform init

# Expected output:
# - Downloading AWS provider
# - Initializing backend
# - Terraform has been successfully initialized!
```

### Step 3: Validate Configuration

```bash
# Check syntax and configuration
terraform validate

# Format code (optional)
terraform fmt -recursive

# Review what will be created
terraform plan -out=tfplan

# Save plan for review
terraform show tfplan > plan.txt
```

### Step 4: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Or use saved plan
terraform apply tfplan

# Review outputs
terraform output
```

**Expected Deployment Time:** 15-20 minutes (CloudFront distribution takes longest)

### Step 5: Deploy Frontend

```bash
cd ~/aws_apps/twin/frontend

# Get S3 bucket name from Terraform output
FRONTEND_BUCKET=$(cd ../terraform && terraform output -raw s3_frontend_bucket)

# Upload frontend files
aws s3 sync . s3://${FRONTEND_BUCKET}/ \
  --exclude "*.md" \
  --exclude ".git/*"

# Verify upload
aws s3 ls s3://${FRONTEND_BUCKET}/
```

### Step 6: Invalidate CloudFront Cache

```bash
cd ~/aws_apps/twin/terraform

# Get CloudFront distribution ID
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || \
  aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='twin-dev'].Id" \
  --output text)

# Create invalidation
aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*"
```

---

## Post-Deployment Tasks

### 1. Verify Deployment

```bash
cd ~/aws_apps/twin/terraform

# Get important URLs
terraform output

# Test API Gateway
API_URL=$(terraform output -raw api_gateway_url)
curl ${API_URL}/health

# Test CloudFront
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)
curl -I ${CLOUDFRONT_URL}
```

### 2. Test Application Functionality

```bash
# Test chat endpoint
curl -X POST ${API_URL}/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello, this is a test",
    "conversation_id": "test-123"
  }'
```

### 3. Configure Frontend API Endpoint

Update `frontend/script.js` with your API Gateway URL:

```javascript
const API_BASE_URL = 'https://your-api-id.execute-api.region.amazonaws.com';
```

Re-upload frontend:
```bash
aws s3 sync frontend/ s3://${FRONTEND_BUCKET}/
aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths "/*"
```

### 4. Set Up Monitoring

```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name twin-dev-dashboard \
  --dashboard-body file://dashboard.json
```

### 5. Enable CloudWatch Logs Insights

```bash
# Query Lambda logs
aws logs tail /aws/lambda/twin-dev-api --follow

# Query with filters
aws logs tail /aws/lambda/twin-dev-api \
  --filter-pattern "ERROR" \
  --follow
```

---

## Custom Domain Setup

### Prerequisites

1. **Domain registered** (Route53 or external registrar)
2. **Route53 hosted zone** created for your domain
3. **Name servers** updated at your registrar

### Configuration Steps

**1. Update terraform.tfvars:**
```hcl
use_custom_domain = true
root_domain       = "yourdomain.com"
```

**2. Apply Terraform:**
```bash
terraform apply
```

**3. Wait for Certificate Validation (5-30 minutes):**
```bash
# Monitor certificate status
aws acm list-certificates --region us-east-1

# Check validation status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID \
  --region us-east-1 \
  --query 'Certificate.Status'
```

**4. Wait for CloudFront Distribution Deployment (15-20 minutes):**
```bash
# Check distribution status
aws cloudfront get-distribution --id ${DISTRIBUTION_ID} \
  --query 'Distribution.Status'
```

**5. Verify DNS Resolution:**
```bash
# Check apex domain
dig yourdomain.com

# Check www subdomain
dig www.yourdomain.com

# Verify HTTPS
curl -I https://yourdomain.com
curl -I https://www.yourdomain.com
```

### DNS Propagation

- **Local/ISP DNS:** 5-30 minutes
- **Global Propagation:** Up to 48 hours
- **Use for testing:** `dig @8.8.8.8 yourdomain.com`

---

## Cost Estimation

### Monthly Cost Breakdown (Dev Environment, Low Traffic)

| Service | Usage | Estimated Cost |
|---------|-------|----------------|
| **S3 Storage** | 1 GB | $0.023 |
| **S3 Requests** | 10,000 GET | $0.004 |
| **Lambda** | 100,000 requests @ 128MB | $0.20 |
| **API Gateway** | 100,000 requests | $0.10 |
| **CloudFront** | 10 GB data transfer | $0.85 |
| **Route53** | Hosted zone (optional) | $0.50 |
| **Bedrock** | 1M input tokens, 100K output | ~$2.00 |
| **CloudWatch Logs** | 1 GB | $0.50 |
| **ACM Certificate** | 1 certificate | $0.00 (Free) |
| **Total (without custom domain)** | | **~$3.67/month** |
| **Total (with custom domain)** | | **~$4.17/month** |

### Production Environment (Higher Traffic)

| Metric | Usage | Estimated Cost |
|--------|-------|----------------|
| **Lambda** | 10M requests @ 256MB | $20.00 |
| **API Gateway** | 10M requests | $10.00 |
| **CloudFront** | 500 GB transfer | $42.50 |
| **Bedrock** | 100M input tokens | ~$200.00 |
| **S3 + Logs** | 50 GB | $2.50 |
| **Total** | | **~$275/month** |

### Cost Optimization Tips

1. **Lambda:**
   - Right-size memory allocation
   - Enable Lambda@Edge for global performance
   - Use provisioned concurrency sparingly

2. **CloudFront:**
   - Use appropriate cache settings
   - Consider PriceClass_100 for lower costs
   - Enable compression

3. **S3:**
   - Use lifecycle policies for old conversations
   - Enable S3 Intelligent-Tiering

4. **Bedrock:**
   - Cache responses when appropriate
   - Use the most cost-effective model
   - Implement request throttling

---

## Security Considerations

### 1. IAM Best Practices

**Least Privilege:**
```hcl
# Instead of AmazonS3FullAccess, create custom policy
resource "aws_iam_policy" "lambda_s3_limited" {
  name = "${local.name_prefix}-lambda-s3-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.memory.arn}/*"
      }
    ]
  })
}
```

### 2. S3 Security

**Enable Encryption:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "memory" {
  bucket = aws_s3_bucket.memory.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Enable Versioning:**
```hcl
resource "aws_s3_bucket_versioning" "memory" {
  bucket = aws_s3_bucket.memory.id
  
  versioning_configuration {
    status = "Enabled"
  }
}
```

### 3. API Security

**Implement API Keys:**
```hcl
resource "aws_apigatewayv2_api_key" "main" {
  name    = "${local.name_prefix}-api-key"
  enabled = true
}
```

**Add WAF Protection:**
```hcl
resource "aws_wafv2_web_acl" "api" {
  name  = "${local.name_prefix}-api-waf"
  scope = "REGIONAL"
  
  # Rate limiting, geo-blocking, etc.
}
```

### 4. CloudFront Security

**Enable Origin Access Control:**
```hcl
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${local.name_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

### 5. Secrets Management

**Never commit secrets to Git:**
```bash
# Use AWS Secrets Manager
aws secretsmanager create-secret \
  --name twin/dev/api-key \
  --secret-string "your-secret-value"
```

**Retrieve in Lambda:**
```python
import boto3
import json

secrets_client = boto3.client('secretsmanager')
response = secrets_client.get_secret_value(SecretId='twin/dev/api-key')
api_key = json.loads(response['SecretString'])
```

### 6. Network Security

**Consider VPC for Lambda:**
```hcl
resource "aws_lambda_function" "api" {
  # ... other configuration ...
  
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}
```

---

## Monitoring & Operations

### CloudWatch Dashboards

Create comprehensive monitoring:

```bash
cat > dashboard.json << 'EOF'
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Invocations", {"stat": "Sum"}],
          [".", "Errors", {"stat": "Sum"}],
          [".", "Duration", {"stat": "Average"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "Lambda Metrics"
      }
    }
  ]
}
EOF

aws cloudwatch put-dashboard \
  --dashboard-name twin-monitoring \
  --dashboard-body file://dashboard.json
```

### CloudWatch Alarms

**Lambda Errors:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name twin-lambda-errors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

**API Gateway 5XX:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name twin-api-5xx \
  --metric-name 5XXError \
  --namespace AWS/ApiGateway \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold
```

### Log Analysis

**CloudWatch Logs Insights Queries:**

```sql
-- Find errors in Lambda logs
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

-- Calculate average duration
fields @timestamp, @duration
| stats avg(@duration) as avg_duration, 
        max(@duration) as max_duration,
        count(*) as invocations
by bin(5m)

-- Track memory usage
fields @timestamp, @maxMemoryUsed / 1000000 as memory_mb
| stats max(memory_mb) as peak_memory
```

### Performance Monitoring

```bash
# Lambda concurrent executions
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --dimensions Name=FunctionName,Value=twin-dev-api \
  --start-time 2025-12-01T00:00:00Z \
  --end-time 2025-12-02T00:00:00Z \
  --period 3600 \
  --statistics Maximum

# API Gateway latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name IntegrationLatency \
  --start-time 2025-12-01T00:00:00Z \
  --end-time 2025-12-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. CloudFront "Pricing Plan" Error

**Error:**
```
You can't delete this distribution while it's subscribed to a pricing plan
```

**Solution:**
```bash
# Disable distribution first
aws cloudfront get-distribution-config --id DIST_ID > config.json
# Edit config.json: set "Enabled": false
aws cloudfront update-distribution --id DIST_ID \
  --if-match ETAG --distribution-config file://config.json

# Wait for deployment (15-30 minutes)
# Then wait for billing cycle to end before deletion
```

#### 2. Lambda "Resource Not Found"

**Error:**
```
Error: creating Lambda Function: InvalidParameterValueException
```

**Solution:**
```bash
# Verify deployment package exists
ls -lh backend/lambda-deployment.zip

# Rebuild package
cd backend
rm lambda-deployment.zip
pip3 install -r requirements.txt -t .
zip -r lambda-deployment.zip .
```

#### 3. API Gateway CORS Issues

**Error:**
```
Access to fetch at 'API_URL' from origin 'CLOUDFRONT_URL' has been blocked by CORS policy
```

**Solution:**
```bash
# Update Lambda CORS_ORIGINS environment variable
aws lambda update-function-configuration \
  --function-name twin-dev-api \
  --environment "Variables={
    CORS_ORIGINS=https://d1234abcd.cloudfront.net,
    S3_BUCKET=twin-dev-memory-123456789012,
    USE_S3=true,
    BEDROCK_MODEL_ID=amazon.nova-micro-v1:0
  }"
```

#### 4. Bedrock "Access Denied"

**Error:**
```
AccessDeniedException: You don't have access to the model
```

**Solution:**
```bash
# Enable model access in Bedrock console
# Or via CLI:
aws bedrock put-model-invocation-logging-configuration \
  --region us-east-1

# Verify model access
aws bedrock list-foundation-models --region us-east-1 \
  --query 'modelSummaries[?modelId==`amazon.nova-micro-v1:0`]'
```

#### 5. Terraform State Lock

**Error:**
```
Error acquiring the state lock
```

**Solution:**
```bash
# Force unlock (use carefully)
terraform force-unlock LOCK_ID

# Or remove local state and re-init
rm -rf .terraform .terraform.lock.hcl
terraform init
```

#### 6. S3 Bucket Already Exists

**Error:**
```
Error: creating S3 Bucket: BucketAlreadyExists
```

**Solution:**
```bash
# Import existing bucket into state
terraform import aws_s3_bucket.frontend twin-dev-frontend-123456789012

# Or use different project_name/environment in tfvars
```

### Debug Commands

```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
terraform plan

# Check AWS CLI configuration
aws configure list
aws sts get-caller-identity

# Verify S3 bucket policy
aws s3api get-bucket-policy --bucket BUCKET_NAME

# Test Lambda function directly
aws lambda invoke \
  --function-name twin-dev-api \
  --payload '{"httpMethod":"GET","path":"/health"}' \
  response.json
cat response.json

# Check CloudFront distribution status
aws cloudfront get-distribution --id DIST_ID \
  --query 'Distribution.Status'
```

---

## Cleanup & Destruction

### Step 1: Empty S3 Buckets

**Critical:** S3 buckets must be empty before Terraform can destroy them.

```bash
# Empty frontend bucket
FRONTEND_BUCKET=$(cd terraform && terraform output -raw s3_frontend_bucket)
aws s3 rm s3://${FRONTEND_BUCKET}/ --recursive

# Empty memory bucket
MEMORY_BUCKET=$(cd terraform && terraform output -raw s3_memory_bucket)
aws s3 rm s3://${MEMORY_BUCKET}/ --recursive

# Verify buckets are empty
aws s3 ls s3://${FRONTEND_BUCKET}/
aws s3 ls s3://${MEMORY_BUCKET}/
```

### Step 2: Destroy Infrastructure

```bash
cd ~/aws_apps/twin/terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Confirm when prompted by typing 'yes'
```

### Step 3: Verify Cleanup

```bash
# Check for remaining resources
aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='twin-dev']"

aws lambda list-functions \
  --query "Functions[?FunctionName=='twin-dev-api']"

aws s3 ls | grep twin-dev

# Check for orphaned IAM roles
aws iam list-roles \
  --query "Roles[?contains(RoleName, 'twin-dev')]"
```

### Manual Cleanup (if needed)

```bash
# Delete CloudFront distribution (if stuck)
DIST_ID="YOUR_DISTRIBUTION_ID"
aws cloudfront get-distribution-config --id ${DIST_ID} > dist-config.json
# Edit dist-config.json: set "Enabled": false
ETAG=$(aws cloudfront get-distribution --id ${DIST_ID} --query 'ETag' --output text)
aws cloudfront update-distribution --id ${DIST_ID} \
  --if-match ${ETAG} --distribution-config file://dist-config.json

# Wait for deployment, then delete
aws cloudfront delete-distribution --id ${DIST_ID} --if-match NEW_ETAG

# Force delete S3 buckets with versioning
aws s3api delete-bucket --bucket ${BUCKET_NAME} --force
```

---

## Appendix

### A. Terraform State Management

**Remote State (Recommended for Teams):**

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "twin/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**Setup:**
```bash
# Create state bucket
aws s3 mb s3://your-terraform-state-bucket

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### B. CI/CD Integration

**GitHub Actions Example:**

```yaml
# .github/workflows/deploy.yml
name: Deploy Twin Application

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.10.0
      
      - name: Terraform Init
        run: |
          cd terraform
          terraform init
      
      - name: Terraform Apply
        run: |
          cd terraform
          terraform apply -auto-approve
```

### C. Useful AWS CLI Commands

```bash
# List all Lambda functions
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,LastModified]' --output table

# Get CloudFront distribution list
aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Status]' --output table

# Check S3 bucket sizes
aws s3 ls | awk '{print $3}' | xargs -I {} aws s3 ls s3://{} --recursive --summarize --human-readable | grep "Total Size"

# View recent Lambda logs
aws logs tail /aws/lambda/twin-dev-api --since 1h --follow

# Get API Gateway endpoints
aws apigatewayv2 get-apis --query 'Items[*].[Name,ApiEndpoint]' --output table
```

### D. Performance Tuning

**Lambda Optimization:**
```python
# Use Lambda layers for dependencies
# Minimize cold start time
# Enable X-Ray tracing

# lambda_handler.py
import os
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

patch_all()

@xray_recorder.capture('handler')
def handler(event, context):
    # Your code here
    pass
```

**CloudFront Optimization:**
```hcl
# Enable compression
resource "aws_cloudfront_distribution" "main" {
  # ...
  
  default_cache_behavior {
    compress = true
    
    # Cache static assets longer
    min_ttl     = 0
    default_ttl = 86400  # 1 day
    max_ttl     = 31536000  # 1 year
  }
}
```

---

## Support and Resources

### Documentation Links

- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **AWS Lambda Developer Guide:** https://docs.aws.amazon.com/lambda/
- **Amazon Bedrock:** https://docs.aws.amazon.com/bedrock/
- **CloudFront Developer Guide:** https://docs.aws.amazon.com/cloudfront/

### Community Resources

- **Terraform Community:** https://discuss.hashicorp.com/
- **AWS Forums:** https://forums.aws.amazon.com/
- **Stack Overflow:** Tag `terraform`, `aws-lambda`, `aws-cloudfront`

### Getting Help

1. **Check CloudWatch Logs** for application errors
2. **Review Terraform state** for infrastructure issues
3. **Use AWS Support** for service-specific problems
4. **GitHub Issues** for code-related questions

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Dec 2025 | Initial release |

---

## License

This deployment guide is provided as-is for use with the Twin application.

---

**End of Document**
EOF

# Move to outputs directory so user can download
mkdir -p /mnt/user-data/outputs
cp README-Deployment-Terraform.md /mnt/user-data/outputs/

echo "✅ README created successfully!"
```

Now let me create the file: