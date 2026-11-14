#!/bin/bash

set -e

if [ $# -eq 0 ]; then
    echo "Usage: bash $0 'name:description:port:source' ..."
    exit 1
fi

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="chinna.online"
hosted_zone_id="Z0579378K5AL0YOAZ116"

MY_IP=$(curl -s https://checkip.amazonaws.com)
declare -A SG_IDS

for ARG in "$@"; do
    # Split each argument by ':' into 4 variables
    IFS=":" read -r NAME DESC PORT SOURCE <<< "$ARG"

    # Replace placeholders with dynamic values
    if [ "$SOURCE" = "MY_IP" ]; then
        SOURCE="${MY_IP}/32"
    elif [ -n "${SG_IDS[$SOURCE]}" ]; then
        SOURCE="${SG_IDS[$SOURCE]}"
    fi

    echo "Creating security group: $NAME..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$NAME" \
        --description "$DESC" \
        --query 'GroupId' \
        --output text)

    # Store the generated GroupId by name for future rules in the loop
    SG_IDS["$NAME"]="$SG_ID"

    # Check if source is a CIDR block (contains '/') or another Security Group ID
    if [[ "$SOURCE" == */* ]]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port "$PORT" \
            --cidr "$SOURCE"
    else
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port "$PORT" \
            --source-group "$SOURCE"
    fi

    echo "Created $NAME ($SG_ID) allowing port $PORT from $SOURCE"

    instance="$NAME"

    if [ $instance != "common" ]; then

        echo "creating instance: $instance"
        instance_id=$(aws ec2 run-instances \
                --image-id $ami_id \
                --instance-type $instance_type \
                --security-group-ids "${SG_IDS["common"]}" "$SG_ID" \
                --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
                --query 'Instances[0].InstanceId' \
                --output text)

        echo "$instance instance ID: $instance_id"

        aws ec2 wait instance-running --instance-ids "$instance_id"

        if [ $instance != "frontend" ]; then
            IP=$(aws ec2 describe-instances \
                --instance-ids $instance_id \
                --query 'Reservations[0].Instances[0].PrivateIpAddress' \
                --output text
            )
            r53_record="$instance.$domain_name"
        else
            IP=$(aws ec2 describe-instances \
                --instance-ids $instance_id \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text
            )
            r53_record="$domain_name"
        fi

        #update route53 record
            echo "Record: ${r53_record}"
                aws route53 change-resource-record-sets \
                --hosted-zone-id $hosted_zone_id \
                --change-batch '{
                    "Changes": [
                        {
                            "Action": "UPSERT",
                            "ResourceRecordSet": {
                                "Name": "'$r53_record'",
                                "Type": "A",
                                "TTL": 1,
                                "ResourceRecords": [{"Value": "'$IP'"}]
                            }
                        }
                    ]
                }'
        echo "Updated route53 record for $instance"
    fi
done