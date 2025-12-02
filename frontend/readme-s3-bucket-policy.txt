 S3 Bucket Policy

bash# Step 1: Disable block public access
aws s3api put-public-access-block \
    --bucket twin-frontend-637423309379 \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# Step 2: Apply bucket policy for CloudFront access
cat << 'EOF' > /tmp/bucket-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::twin-frontend-637423309379/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::637423309379:distribution/E7PY9GL1Z6YJ4"
                }
            }
        },
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::twin-frontend-637423309379/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket twin-frontend-637423309379 --policy file:///tmp/bucket-policy.json

# Step 3: Invalidate CloudFront cache
aws cloudfront create-invalidation \
    --distribution-id E7PY9GL1Z6YJ4 \
    --paths "/*"

Verify
After running the above, test both URLs:

# Test S3 website
bijut@b:~/aws_apps/twin/frontend$ curl -I http://twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com
HTTP/1.1 200 OK
x-amz-id-2: mBa/88fvEMussub4XDUuWQlzCgHkclAjp5QGiuripGxuQLP+mmx75MEPyLB1X9DNMf3AYucl9wS1yUHzvnreX+T+gVESs0EL4qECVkzxcz8=
x-amz-request-id: KJABX7CK4T4SY82P
Date: Tue, 02 Dec 2025 07:22:33 GMT
Last-Modified: Tue, 02 Dec 2025 07:18:25 GMT
ETag: "e2d878879116968403e616e98f6fba3d"
Content-Type: text/html
Content-Length: 9607
Server: AmazonS3

bijut@b:~/aws_apps/twin/frontend$



# Test CloudFront (may take 1-2 minutes to propagate)
bijut@b:~/aws_apps/twin/frontend$ curl -I https://d1qgfadvq9sf62.cloudfront.net
HTTP/2 403
x-amz-error-code: AccessDenied
x-amz-error-message: Access Denied
server: AmazonS3
date: Tue, 02 Dec 2025 07:22:47 GMT
x-cache: Error from cloudfront
via: 1.1 4b259f0713185d35b300d672958b1cb6.cloudfront.net (CloudFront)
x-amz-cf-pop: LAX54-P8
x-amz-cf-id: 64Gu4X2WnWq-NbdrSKyUX0ZdDkPsqa7F0Hx59K3fVF5VPyVt2c2prQ==

bijut@b:~/aws_apps/twin/frontend$


Then open in your browser:
https://d1qgfadvq9sf62.cloudfront.net

403 Forbidden
Code: AccessDenied
Message: Access Denied
RequestId: Z7V505H3YM0KZ8CD
HostId: /DrbEay0v58AX8ZisBX57kdCb8npnaFo6qQUQCOUSl3I1N3s5Nb9tvi+0oPHYJ7Zk1mLDhC9d7I=
An Error Occurred While Attempting to Retrieve a Custom Error Document
Code: AccessDenied
Message: Access Denied


bijut@b:~/aws_apps/twin/frontend$ aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 --query "DistributionConfig.Origins.Items[0]" --output json
{
    "Id": "twin-frontend-chatbox.s3-website-us-east-1.amazonaws.com-minj67ota96",
    "DomainName": "twin-frontend-chatbox.s3-website-us-east-1.amazonaws.com",
    "OriginPath": "",
    "CustomHeaders": {
        "Quantity": 0
    },
    "CustomOriginConfig": {
        "HTTPPort": 80,
        "HTTPSPort": 443,
        "OriginProtocolPolicy": "http-only",
        "OriginSslProtocols": {
            "Quantity": 4,
            "Items": [
                "SSLv3",
                "TLSv1",
                "TLSv1.1",
                "TLSv1.2"
            ]
        },
        "OriginReadTimeout": 30,
        "OriginKeepaliveTimeout": 5,
        "IpAddressType": "ipv4"
    },
    "ConnectionAttempts": 3,
    "ConnectionTimeout": 10,
    "OriginShield": {
        "Enabled": false
    },
    "OriginAccessControlId": ""
}
bijut@b:~/aws_apps/twin/frontend$

The problem is clear now. CloudFront is pointing to the wrong S3 bucket:

CloudFront origin: twin-frontend-chatbox.s3-website-us-east-1.amazonaws.com
Your actual bucket: twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com

Update CloudFront Origin
# Get current config
aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 > /tmp/cf-config.json

# Extract ETag
ETAG=$(jq -r '.ETag' /tmp/cf-config.json)
echo "ETag: $ETAG"

# Extract DistributionConfig and update the origin domain
jq '.DistributionConfig' /tmp/cf-config.json | \
  sed 's/twin-frontend-chatbox\.s3-website-us-east-1\.amazonaws\.com/twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com/g' > /tmp/cf-dist-config.json

# Update CloudFront distribution
aws cloudfront update-distribution \
    --id E7PY9GL1Z6YJ4 \
    --if-match "$ETAG" \
    --distribution-config file:///tmp/cf-dist-config.json

ETag: E3R9UTHXTXEHXL
{
    "ETag": "E1MKQEVQJ4QMHD",
    "Distribution": {
        "Id": "E7PY9GL1Z6YJ4",
        "ARN": "arn:aws:cloudfront::637423309379:distribution/E7PY9GL1Z6YJ4",
        "Status": "InProgress",
        "LastModifiedTime": "2025-12-02T07:27:44.269000+00:00",
        "InProgressInvalidationBatches": 0,
        "DomainName": "d1qgfadvq9sf62.cloudfront.net",
        "ActiveTrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        },
        "ActiveTrustedKeyGroups": {
            "Enabled": false,
            "Quantity": 0
        },
        "DistributionConfig": {
            "CallerReference": "dda986cf-afb2-469a-afed-04112d7dddb5",
            "Aliases": {
                "Quantity": 0
            },
            "DefaultRootObject": "",
            "Origins": {
                "Quantity": 1,
                "Items": [
                    {
                        "Id": "twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com-minj67ota96",
                        "DomainName": "twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com",
                        "OriginPath": "",
                        "CustomHeaders": {
                            "Quantity": 0
                        },
                        "CustomOriginConfig": {
                            "HTTPPort": 80,
                            "HTTPSPort": 443,
                            "OriginProtocolPolicy": "http-only",
                            "OriginSslProtocols": {
                                "Quantity": 4,
                                "Items": [
                                    "SSLv3",
                                    "TLSv1",
                                    "TLSv1.1",
                                    "TLSv1.2"
                                ]
                            },
                            "OriginReadTimeout": 30,
                            "OriginKeepaliveTimeout": 5,
                            "IpAddressType": "ipv4"
                        },
                        "ConnectionAttempts": 3,
                        "ConnectionTimeout": 10,
                        "OriginShield": {
                            "Enabled": false
                        },
                        "OriginAccessControlId": ""
                    }
                ]
            },
            "OriginGroups": {
                "Quantity": 0
            },
            "DefaultCacheBehavior": {
                "TargetOriginId": "twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com-minj67ota96",
                "TrustedSigners": {
                    "Enabled": false,
                    "Quantity": 0
                },
                "TrustedKeyGroups": {
                    "Enabled": false,
                    "Quantity": 0
                },
                "ViewerProtocolPolicy": "redirect-to-https",
                "AllowedMethods": {
                    "Quantity": 2,
                    "Items": [
                        "HEAD",
                        "GET"
                    ],
                    "CachedMethods": {
                        "Quantity": 2,
                        "Items": [
                            "HEAD",
                            "GET"
                        ]
                    }
                },
                "SmoothStreaming": false,
                "Compress": true,
                "LambdaFunctionAssociations": {
                    "Quantity": 0
                },
                "FunctionAssociations": {
                    "Quantity": 0
                },
                "FieldLevelEncryptionId": "",
                "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                "GrpcConfig": {
                    "Enabled": false
                }
            },
            "CacheBehaviors": {
                "Quantity": 0
            },
            "CustomErrorResponses": {
                "Quantity": 0
            },
            "Comment": "",
            "Logging": {
                "Enabled": false,
                "IncludeCookies": false,
                "Bucket": "",
                "Prefix": ""
            },
            "PriceClass": "PriceClass_All",
            "Enabled": true,
            "ViewerCertificate": {
                "CloudFrontDefaultCertificate": true,
                "SSLSupportMethod": "vip",
                "MinimumProtocolVersion": "TLSv1",
                "CertificateSource": "cloudfront"
            },
            "Restrictions": {
                "GeoRestriction": {
                    "RestrictionType": "none",
                    "Quantity": 0
                }
            },
            "WebACLId": "arn:aws:wafv2:us-east-1:637423309379:global/webacl/CreatedByCloudFront-c3083e55/71a999d8-8e14-47de-adc2-05865261bea3",
            "HttpVersion": "http2",
            "IsIPV6Enabled": true,
            "ContinuousDeploymentPolicyId": "",
            "Staging": false
        }
    }
}
bijut@b:~/aws_apps/twin/frontend$


Verify the Change
bijut@b:~/aws_apps/twin/frontend$ # Check the updated origin
aws cloudfront get-distribution-config --id E7PY9GL1Z6YJ4 --query "DistributionConfig.Origins.Items[0].DomainName" --output text
twin-frontend-637423309379.s3-website-us-east-1.amazonaws.com
bijut@b:~/aws_apps/twin/frontend$

Wait and Test
CloudFront takes ~5 minutes to deploy. Check status:
bijut@b:~/aws_apps/twin/frontend$ aws cloudfront get-distribution --id E7PY9GL1Z6YJ4 --query "Distribution.Status" --output text
InProgress
bijut@b:~/aws_apps/twin/frontend$
Deployed
bijut@b:~/aws_apps/twin/frontend$ curl -I https://d1qgfadvq9sf62.cloudfront.net
HTTP/2 200
content-type: text/html
content-length: 9607
date: Tue, 02 Dec 2025 07:29:15 GMT
last-modified: Tue, 02 Dec 2025 07:18:25 GMT
etag: "e2d878879116968403e616e98f6fba3d"
server: AmazonS3
x-cache: Miss from cloudfront
via: 1.1 10faada4ebdd7073a754053de96f4890.cloudfront.net (CloudFront)
x-amz-cf-pop: LAX54-P8
x-amz-cf-id: 8TdGRaAs479IuBPPOYMjneQ-WqMK8Hr_H3cN3GRoWou8nvOPo3xQFg==

bijut@b:~/aws_apps/twin/frontend$

