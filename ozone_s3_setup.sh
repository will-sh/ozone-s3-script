#!/bin/bash

if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found, installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI installation failed!"
        exit 1
    fi
else
    echo "AWS CLI is already installed."
fi

hostname="ccycloud-1.will-xiao.root.comops.site"
username="admin"
password="admin"

# Step 1: Get Cluster Info
API_URL_1="https://$hostname:7183/api/v54/clusters?clusterType=base&view=summary"
response_1=$(curl -s -u "$username:$password" -k "$API_URL_1" -H "accept: application/json")
cluster_name=$(echo "$response_1" | jq -r '.items[0].name')
encoded_cluster_name=$(echo "$cluster_name" | sed 's/ /%20/g')

# Step 2: Get Ozone S3 Gateway Info
API_URL_2="https://$hostname:7183/api/v54/clusters/$encoded_cluster_name/getOzoneS3GatewayInfo?bucketName=test-bucket"
response_2=$(curl -s -u "$username:$password" -k -X POST "$API_URL_2" -H "accept: application/json")
aws_access_key=$(echo "$response_2" | jq -r '.awsAccessKey')
aws_secret=$(echo "$response_2" | jq -r '.awsSecret')
restUrl=$(echo "$response_2" | jq -r '.restUrl')

# Configure AWS CLI
if [[ -n "$aws_access_key" && -n "$aws_secret" ]]; then
    aws configure set aws_access_key_id "$aws_access_key"
    aws configure set aws_secret_access_key "$aws_secret"
    aws configure set default.region us-east-1
    echo "AWS CLI configured successfully."
else
    echo "Error: Failed to extract credentials."
    exit 1
fi

# SSL Configuration
truststore_password=$(grep -A1 'ssl.client.truststore.password' /etc/ozone/conf.cloudera.OZONE-1/ssl-client.xml | grep -oP '(?<=<value>).*?(?=</value>)')
keystore_path="/var/lib/cloudera-scm-agent/agent-cert/cm-auto-global_truststore.jks"
alias="cmrootca-0"
export_cert_path="$(dirname "$0")/s3g-ca.crt"
/usr/java/default/bin/keytool -export -alias "$alias" -file "$export_cert_path" -keystore "$keystore_path" -storepass "$truststore_password"
pem_cert_path="$(dirname "$0")/s3g-ca.pem"
openssl x509 -inform DER -in "$export_cert_path" -out "$pem_cert_path"

# Verify SSL Certificate Export
if [[ $? -eq 0 ]]; then
    echo "Certificate exported successfully."
else
    echo "Error exporting certificate."
    exit 1
fi

# Save variables to a temporary file
temp_file="$(dirname "$0")/setup_variables.env"
echo "REST_URL=$restUrl" > "$temp_file"
echo "PEM_CERT_PATH=$pem_cert_path" >> "$temp_file"

echo "Setup complete. Variables saved to $temp_file."

