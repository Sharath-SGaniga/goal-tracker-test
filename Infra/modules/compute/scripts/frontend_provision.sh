#!/bin/bash
# Frontend provisioning script

# Make sure we're running with root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Using sudo..."
  exec sudo "$0" "$@"
fi

# Install necessary packages
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl software-properties-common dnsutils

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
if [ -n "${dockerhub_username}" ] && [ -n "${dockerhub_password}" ]; then
  echo "Logging into Docker Hub using provided credentials..."
  echo "${dockerhub_password}" | docker login -u "${dockerhub_username}" --password-stdin
  if [ $? -ne 0 ]; then
    echo "Failed to perform Docker login to Docker Hub. Please check credentials and Docker setup."
    exit 1
  fi
  echo "Successfully logged into Docker Hub."
else
  echo "No Docker Hub credentials provided, assuming public image or pre-authenticated environment."
fi

# Pull container image
echo "Pulling Docker image: ${full_image_name}"
docker pull "${full_image_name}"

# Use backend LB IP provided by Terraform
backend_lb_ip="${backend_lb_ip}"
echo "Using backend load balancer IP: $backend_lb_ip"

# If no IP was provided, try to discover it
if [ -z "$backend_lb_ip" ]; then
  echo "No backend LB IP provided, attempting to discover it..."
  # Try to find the backend load balancer by scanning the subnet
  for subnet in "10.0.3" "10.0.4"; do
    # Search the common IP range where internal load balancers are deployed
    for last_octet in $(seq 1 10); do
      potential_ip="$subnet.$last_octet"
      echo "Testing connectivity to potential backend at $potential_ip:8080..."
      if nc -z -w 1 $potential_ip 8080 2>/dev/null; then
        echo "Found backend load balancer at $potential_ip:8080"
        backend_lb_ip=$potential_ip
        break 2
      fi
    done
  done

  # Use default if discovery failed
  if [ -z "$backend_lb_ip" ]; then
    echo "Warning: Could not detect backend load balancer, using default value 10.0.3.4"
    backend_lb_ip="10.0.3.4"
  fi
fi

echo "Running Docker container with backend URL: http://${backend_lb_ip}:8080"
# Frontend container with properly configured backend URL
docker run -d -p "${application_port}:${application_port}" \
  -e PORT="${application_port}" \
  -e BACKEND_URL="http://${backend_lb_ip}:8080" \
  --restart always \
  "${full_image_name}"

# Log the completion
echo "Frontend provisioning completed at $(date)" >> /var/log/provision.log
echo "Script finished. Check /var/log/provision.log and docker logs for status."