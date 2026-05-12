#!/bin/bash
# Backend provisioning script

# Make sure we're running with root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Using sudo..."
  exec sudo "$0" "$@"
fi

# Access template variables 
# Note: these come from the template_file resource in main.tf
application_port="${application_port}"
full_image_name="${full_image_name}"
dockerhub_username="${dockerhub_username}"
dockerhub_password="${dockerhub_password}"
key_vault_id="${key_vault_id}"

# Install necessary packages
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl software-properties-common dnsutils jq

# Install Docker
echo "Setting up Docker repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
echo "Installing Docker..."
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Start and enable docker service
echo "Starting and enabling Docker service..."
systemctl enable docker
systemctl start docker

# Add adminuser to the docker group
echo "Adding 'adminuser' to the docker group..."
usermod -aG docker adminuser
if [ $? -eq 0 ]; then
  echo "'adminuser' successfully added to the docker group. User will need to log out and log back in for this to take effect in interactive shells."
else
  echo "Warning: Failed to add 'adminuser' to the docker group. Docker commands may require sudo for this user in interactive shells."
fi

# Configure Docker Hub authentication if credentials are provided
if [ -n "$dockerhub_username" ] && [ -n "$dockerhub_password" ]; then
  echo "Logging into Docker Hub using provided credentials..."
  echo "$dockerhub_password" | docker login -u "$dockerhub_username" --password-stdin
  if [ $? -ne 0 ]; then
    echo "Failed to perform Docker login to Docker Hub. Please check credentials and Docker setup."
    exit 1
  fi
  echo "Successfully logged into Docker Hub."
else
  echo "No Docker Hub credentials provided, assuming public image or pre-authenticated environment."
fi

# Pull container image
echo "Pulling Docker image: $full_image_name"
docker pull "$full_image_name"

# Get Key Vault name from the Key Vault ID
KEY_VAULT_NAME=$(echo "$key_vault_id" | awk -F/ '{print $NF}')
echo "Using Key Vault: $KEY_VAULT_NAME"

# Explicitly login with Managed Identity
echo "Logging in to Azure CLI using managed identity..."
az login --identity --allow-no-subscriptions
if [ $? -ne 0 ]; then
  echo "Failed to login using managed identity. Retrying with more information..."
  # Get the managed identity's client ID to use for explicit login
  IDENTITY_ENDPOINT=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/identity/info?api-version=2018-02-01" | jq -r '.clientId')
  if [ -n "$IDENTITY_ENDPOINT" ]; then
    echo "Using client ID: $IDENTITY_ENDPOINT for login"
    az login --identity --username "$IDENTITY_ENDPOINT" --allow-no-subscriptions
  else
    echo "Could not determine managed identity client ID. Using default managed identity."
    az login --identity --allow-no-subscriptions
  fi
fi

# Get secrets from Key Vault using Managed Identity
echo "Retrieving database credentials from Key Vault using Managed Identity..."
DB_USERNAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-username" --query "value" -o tsv)
DB_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-password" --query "value" -o tsv)
DB_HOST=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-host" --query "value" -o tsv)
DB_NAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-name" --query "value" -o tsv)
DB_PORT=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-port" --query "value" -o tsv)
SSL_MODE=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-sslmode" --query "value" -o tsv)

# Verify all required secrets were retrieved
if [ -z "$DB_USERNAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_PORT" ] || [ -z "$SSL_MODE" ]; then
  echo "ERROR: Failed to retrieve all required database secrets from Key Vault. Provisioning cannot continue."
  echo "Missing secrets:"
  [ -z "$DB_USERNAME" ] && echo "- db-username"
  [ -z "$DB_PASSWORD" ] && echo "- db-password"
  [ -z "$DB_HOST" ] && echo "- db-host"
  [ -z "$DB_NAME" ] && echo "- db-name"
  [ -z "$DB_PORT" ] && echo "- db-port"
  [ -z "$SSL_MODE" ] && echo "- db-sslmode"
  exit 1
fi

echo "Successfully retrieved all database configuration from Key Vault."

# Ensure DNS resolution is working before trying to connect to the database
echo "Checking DNS resolution for database host: $DB_HOST"
max_attempts=20
attempt=1
while [ $attempt -le $max_attempts ]; do
  echo "DNS resolution attempt $attempt of $max_attempts..."
  if nslookup "$DB_HOST" > /dev/null 2>&1; then
    echo "Successfully resolved database host: $DB_HOST"
    break
  else
    echo "Failed to resolve database host. Waiting 15 seconds before retry..."
    sleep 15
    attempt=$((attempt+1))
  fi
done

if [ $attempt -gt $max_attempts ]; then
  echo "Failed to resolve database host after $max_attempts attempts. Proceeding anyway..."
fi

# Backend container needs DB environment variables
echo "Running Docker container..."
docker run -d -p "$application_port:$application_port" \
  -e DB_USERNAME="$DB_USERNAME" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_HOST="$DB_HOST" \
  -e DB_PORT="$DB_PORT" \
  -e DB_NAME="$DB_NAME" \
  -e SSL="$SSL_MODE" \
  -e PORT="$application_port" \
  --restart always \
  "$full_image_name"

# Log the completion
echo "Backend provisioning completed at $(date)" >> /var/log/provision.log
echo "Script finished. Check /var/log/provision.log and docker logs for status."