#!/bin/bash
# Collect lab evidence into evidence.txt. Run in AWS CloudShell.
# No "set -e": a failing command is recorded and the script continues.
if [ $# -ne 3 ]; then
  echo "Usage: $0 <bucket> <ec2-address> <lambda-address>" >&2
  exit 1
fi
BUCKET=$1
# Accept addresses with or without scheme and trailing slash.
norm() { local a=${1%%/}; case $a in http://*|https://*) echo "$a";; *) echo "$2://$a";; esac; }
EC2=$(norm "$2" http)
LAM=$(norm "$3" https)
EC2_NAME=cv-ec2-23l-3032
EC2_ROLE=cv-ec2-role-23l-3032
LAMBDA_ROLE=cv-lambda-role-23l-3032
FN=cv-func-23l-3032

run() {
  local out
  if out=$("$@" 2>&1); then
    printf '%s\n' "$out"
  else
    printf '%s\nCOMMAND FAILED: %s\n' "$out" "$*"
  fi
}

# Print each inline policy document of a role.
inline_policies() {
  local names n
  names=$(aws iam list-role-policies --role-name "$1" --query PolicyNames --output text 2>/dev/null)
  for n in $names; do
    run aws iam get-role-policy --role-name "$1" --policy-name "$n"
  done
}

probe() {
  local r
  r=$(curl -s -m 15 -o /dev/null -w "%{http_code} %{content_type}" "$2") || echo "COMMAND FAILED: curl $2"
  echo "$1 $2 -> $r"
}

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$EC2_NAME" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | awk '{print $1}')

{
  echo "== caller =="
  run aws sts get-caller-identity

  echo "== public-access =="
  run aws s3api get-public-access-block --bucket "$BUCKET"

  echo "== versioning =="
  run aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo "== objects =="
  run aws s3 ls "s3://$BUCKET/site/"

  echo "== ec2-policy =="
  run aws iam list-role-policies --role-name "$EC2_ROLE"
  inline_policies "$EC2_ROLE"

  echo "== lambda-policy =="
  run aws iam list-attached-role-policies --role-name "$LAMBDA_ROLE"
  run aws iam list-role-policies --role-name "$LAMBDA_ROLE"
  inline_policies "$LAMBDA_ROLE"

  echo "== security-group =="
  if [ -n "$INSTANCE_ID" ]; then
    SGS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text 2>/dev/null)
    # shellcheck disable=SC2086
    run aws ec2 describe-security-groups --group-ids $SGS \
      --query 'SecurityGroups[].{Id:GroupId,Name:GroupName,Inbound:IpPermissions}'
  else
    echo "COMMAND FAILED: find running instance with tag Name=$EC2_NAME"
  fi

  echo "== instance =="
  run aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$EC2_NAME" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,InstanceType:InstanceType,HttpTokens:MetadataOptions.HttpTokens,ProfileArn:IamInstanceProfile.Arn,PublicIp:PublicIpAddress}'

  echo "== endpoints =="
  probe EC2 "$EC2/"
  probe EC2 "$EC2/style.css"
  probe EC2 "$EC2/cv.pdf"
  probe Lambda "$LAM/"
  probe Lambda "$LAM/style.css"
  probe Lambda "$LAM/cv.pdf"
  probe Lambda "$LAM/anything"
  probe S3 "https://$BUCKET.s3.amazonaws.com/site/index.html"

  echo "== lambda-logs =="
  run aws logs tail "/aws/lambda/$FN" --since 1h | tail -n 20

  echo "== log-retention =="
  run aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$FN" \
    --query 'logGroups[].{Name:logGroupName,retentionInDays:retentionInDays}'
} > evidence.txt 2>&1

echo DONE
