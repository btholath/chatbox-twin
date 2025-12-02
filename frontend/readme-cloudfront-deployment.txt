

Cloudfront: d1qgfadvq9sf62.cloudfront.net)


# Check if files exist in S3
aws s3 ls s3://twin-frontend-637423309379/

# If empty, build and deploy frontend
cd ~/aws_apps/twin/frontend
npm install
npm run build
aws s3 sync out/ s3://twin-frontend-637423309379/ --delete

Fix CloudFront/S3 Permissions
# Get CloudFront distribution ID
DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?DomainName=='d1qgfadvq9sf62.cloudfront.net'].Id" --output text)
echo "Distribution ID: $DIST_ID"

# Then apply bucket policy (replace DIST_ID below)


aws s3 ls s3://twin-frontend-637423309379/