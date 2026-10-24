#!/bin/bash
# Sync the CV site from S3 to the web root and stamp the footer with this instance id.
BUCKET=cv-23l-3032
STAGING=/opt/cv/staging
WEB=/var/www/html
LOG=/var/log/cv-sync.log
IMDS=http://169.254.169.254/latest

TOKEN=$(curl -s -X PUT "$IMDS/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
imds() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/$1"; }
ID=$(imds instance-id)
REGION=$(imds placement/region)

mkdir -p "$STAGING"
STATUS=FAILED
if aws s3 sync "s3://$BUCKET/site/" "$STAGING/" --delete --region "$REGION" \
   && cp -r "$STAGING"/. "$WEB"/; then
  STATUS=SUCCESS
fi

# Runs even on failure so the raw placeholder is never served.
if [ -f "$WEB/index.html" ] && ! sed -i "s/{{HOSTED_ON}}/EC2 ${ID:-unknown}/" "$WEB/index.html"; then
  STATUS=FAILED
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $STATUS" >> "$LOG"
[ "$STATUS" = SUCCESS ]
