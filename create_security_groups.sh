#!/bin/bash
MY_IP=$(curl -s https://checkip.amazonaws.com);

SSH=$(aws ec2 create-security-group \
    --group-name common \
    --description "Allow SSH access" \
    --query 'GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$SSH" \
    --protocol tcp \
    --port 22 \
    --cidr "${MY_IP}/32"

FRONTEND=$(aws ec2 create-security-group \
    --group-name frontend \
    --description "Allow HTTP access" \
    --query 'GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$FRONTEND" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

BACKEND=$(aws ec2 create-security-group \
    --group-name backend \
    --description "Allow NodeJS access" \
    --query 'GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$BACKEND" \
    --protocol tcp \
    --port 8080 \
    --source-group "$FRONTEND"

DB=$(aws ec2 create-security-group \
    --group-name database \
    --description "Allow MySQL access" \
    --query 'GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$DB" \
    --protocol tcp \
    --port 3306 \
    --source-group "$BACKEND"

