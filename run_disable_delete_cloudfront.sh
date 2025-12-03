===============================================================
1. Disable the distribution first (if not already disabled):
===============================================================
# Get current config and ETag
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID

# Disable it
aws cloudfront get-distribution-config --id YOUR_DISTRIBUTION_ID > config.json
# Edit config.json and set "Enabled": false
aws cloudfront update-distribution --id YOUR_DISTRIBUTION_ID --if-match ETAG_VALUE --distribution-config file://config.json


aws cloudfront  get-distribution-config --id E7PY9GL1Z6YJ4  > config.json
aws cloudfront update-distribution --id E7PY9GL1Z6YJ4  --distribution-config file://config.json



===============================================================
2. Wait for deployment to complete:
===============================================================
The distribution status must change from "In Progress" to "Deployed"
This can take 15-30 minutes
Check status: aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID




===============================================================
3. Get the LATEST ETag:
===============================================================
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID --query 'ETag' --output text
aws cloudfront get-distribution --id E7PY9GL1Z6YJ4 --query 'ETag' --output text


===============================================================
4. Delete with the current ETag:
===============================================================
aws cloudfront delete-distribution --id YOUR_DISTRIBUTION_ID --if-match CURRENT_ETAG
aws cloudfront delete-distribution --id E7PY9GL1Z6YJ4 --if-match E3G4F884GQXMTL

===============================================================
If using the AWS Console:
===============================================================

Disable the distribution (click distribution → Disable)
Wait until Status shows "Deployed" (not "In Progress")
Refresh the page to get the latest state
Delete the distribution

Key points:

The ETag changes every time the distribution is modified
You must use the most recent ETag value
The distribution must be disabled AND fully deployed before deletion
Don't skip the waiting step - trying to delete while "In Progress" will fail


===============================================================
Troubleshooting
===============================================================
bijut@b:~/aws_apps/twin$ aws cloudfront delete-distribution --id E7PY9GL1Z6YJ4 --if-match E3G4F884GQXMTL

An error occurred (PreconditionFailed) when calling the DeleteDistribution operation:
You can't delete this distribution while it's subscribed to a pricing plan.
After you cancel the pricing plan, you can delete the distribution at the end of monthly billing cycle.
bijut@b:~/aws_apps/twin$

Step 1: Change to a free pricing class
# Get the current distribution config
aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 > distribution-config.json

# Save the ETag for later
aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 --query 'ETag' --output text
E3G4F884GQXMTL

Now edit distribution-config.json and change the PriceClass field to the lowest tier
"PriceClass": "PriceClass_100"

Then update the distribution:
# Replace ETAG_VALUE with the ETag from above
aws cloudfront update-distribution-config \
  --id E7PY9GL1Z6YJ4 \
  --if-match ETAG_VALUE \
  --distribution-config file://distribution-config.json

run below command:
aws cloudfront update-distribution \
  --id E7PY9GL1Z6YJ4 \
  --if-match E3G4F884GQXMTL \
  --distribution-config file://distribution-config.json

or run below command
# Get config, modify PriceClass, and update in one go
aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 > temp.json

# Extract just the DistributionConfig part and modify PriceClass
jq '.DistributionConfig | .PriceClass = "PriceClass_100"' temp.json > distribution-config.json

# Get the current ETag
ETAG=$(jq -r '.ETag' temp.json)

# Update the distribution
aws cloudfront update-distribution \
  --id E7PY9GL1Z6YJ4 \
  --if-match $ETAG \
  --distribution-config file://distribution-config.json

### Below command worked !!!
# Get fresh config
aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 > temp.json

# Disable it
jq '.DistributionConfig | .Enabled = false' temp.json > distribution-config.json

ETAG=$(jq -r '.ETag' temp.json)

aws cloudfront update-distribution \
  --id E7PY9GL1Z6YJ4 \
  --if-match $ETAG \
  --distribution-config file://distribution-config.json

# Wait for deployment (15-30 minutes) - Check status with:
bijut@b:~/aws_apps/twin$ aws cloudfront get-distribution --id E7PY9GL1Z6YJ4 --query 'Distribution.Status'
"Deployed"
bijut@b:~/aws_apps/twin$

Once it shows "Deployed", the "pricing plan" restriction likely refers to your AWS billing cycle. You'll need to:

Wait until the end of your current monthly billing period
Check your billing cycle end date in the AWS Billing Console
Only then can you delete the distribution

This is AWS's policy to ensure they can properly bill you for the current period. There's unfortunately no way to bypass this waiting period.
==========================================================================================