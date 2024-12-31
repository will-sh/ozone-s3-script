#!/bin/bash

# Call the setup script to ensure configuration
setup_script="$(dirname "$0")/ozone_s3_setup.sh"
temp_file="$(dirname "$0")/setup_variables.env"

if [[ ! -f "$temp_file" ]]; then
    echo "Running setup script..."
    bash "$setup_script"
fi

# Load setup variables
if [[ -f "$temp_file" ]]; then
    source "$temp_file"
else
    echo "Error: Setup variables file not found!"
    exit 1
fi

# Function: Define alias for AWS S3 API
ozones3api() {
    aws s3api --endpoint "$REST_URL" --ca-bundle "$PEM_CERT_PATH" "$@"
}

# Function: Create S3 bucket
create_bucket() {
    local bucket_name=$1
    echo "Creating S3 bucket '$bucket_name'..."
    ozones3api create-bucket --bucket="$bucket_name"

    if [[ $? -eq 0 ]]; then
        echo "Bucket '$bucket_name' created successfully."
    else
        echo "Error creating S3 bucket."
        exit 1
    fi
}

# Function: Upload file to the specified S3 bucket
put_object() {
    local bucket_name=$1
    local key=$2
    local body=$3

    if [[ ! -f "$body" ]]; then
        echo "Error: File '$body' not found."
        exit 1
    fi

    echo "Uploading '$body' to bucket '$bucket_name' with key '$key'..."
    ozones3api put-object --bucket "$bucket_name" --key "$key" --body "$body"

    if [[ $? -eq 0 ]]; then
        echo "File '$body' uploaded successfully to bucket '$bucket_name' with key '$key'."
    else
        echo "Error uploading file."
        exit 1
    fi
}


# Example usage of the functions
create_bucket "wordcount"
put_object "wordcount" "file1" "./files/file1"
