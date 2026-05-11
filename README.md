# CloudOps Goal Tracker - Three-Tier Architecture

This project demonstrates a modern three-tier architecture:

1. **Presentation Layer (Frontend)**: Node.js/Express server serving a JavaScript frontend
2. **Business Logic Layer (Backend)**: Go API service 
3. **Data Layer**: PostgreSQL database

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Frontend    │     │     Backend     │     │    Database     │
│    (Node.js)    │────▶│      (Go)       │────▶│   (PostgreSQL)  │
│   Port: 3000    │     │   Port: 8080    │     │    Port: 5432   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                 
```

## Running the Application

You can run the entire application stack using Docker Compose:

```bash
cd docker-local-deployment
docker-compose up -d
```

### Accessing Components

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8080


## Developing Components Individually

### Frontend Development

```bash
cd frontend
npm install
npm start
```

The frontend is a Node.js/Express application that:
- Serves static files from the `/public` directory
- Provides API proxying to the backend
- Handles all user interactions

### Backend Development

```bash
cd backend
go mod download
go run main.go
```

The backend is a Go API service that:
- Provides JSON REST API endpoints
- Connects to the PostgreSQL database
- Implements business logic
- Exposes metrics for monitoring

### Data Layer

The PostgreSQL database:
- Stores goal tracking data
- Initializes with the schema defined in `docker-local-deployment/database/init.sql`

## API Endpoints

### Backend API (Go Service)

- `GET /goals` - Get all goals
- `POST /goals` - Add a new goal
- `DELETE /goals/:id` - Delete a goal by ID
- `GET /health` - Health check endpoint
- `GET /metrics` - Prometheus metrics endpoint

### Frontend API Proxy (Node.js)

- `GET /api/goals` - Proxy to backend's GET /goals
- `POST /api/goals` - Proxy to backend's POST /goals
- `DELETE /api/goals/:id` - Proxy to backend's DELETE /goals/:id

## Local Deployment using Docker Compose
### Prerequisites
- Docker (version 20.10+)
- Docker Compose (version 2.0+)
### Step 1: Go to the docker-local-deployment directory
```bash
cd docker-local-deployment
```
### Step 2: Copy paste the below command to run the application
```bash
docker-compose up -d
```
### Step 3: Access the application
- Frontend: http://localhost:3000
- Backend API: http://localhost:8080
- Database: http://localhost:5432 (use pgAdmin or any other client to connect ) 



# 3-Tier Application Infrastructure on Azure

This Terraform project deploys a secure and scalable 3-tier application infrastructure in Azure, consisting of frontend, backend, and database tiers.

## Architecture Overview


### Components

1. **Frontend Tier:**
   - Node.js application running in Docker containers
   - VM Scale Set with auto-scaling
   - Application Gateway with WAF for security
   - Deployed in public subnets across 2 availability zones

2. **Backend Tier:**
   - Go application running in Docker containers
   - VM Scale Set with auto-scaling
   - Internal Load Balancer
   - Deployed in private subnets across 2 availability zones

3. **Database Tier:**
   - Azure Database for PostgreSQL Flexible Server
   - Primary server with read-write capability
   - Read replica for read-only operations
   - Deployed in database subnets across 2 availability zones

4. **Supporting Infrastructure:**
   - Docker Hub for container images
   - Azure Key Vault for secrets management (including Docker Hub credentials)
   - Azure Bastion for secure SSH access
   - Private DNS Zones for name resolution
   - Network Security Groups for each subnet

## Prerequisites

- Azure CLI installed and configured
- Terraform v1.5.0 or later
- Azure subscription and permissions to create resources
- Docker installed locally for building and pushing container images

## Service Principal Setup for Terraform

Before deploying infrastructure with Terraform, you need to create a service principal with contributor permissions. This allows Terraform to authenticate with Azure and create resources on your behalf.

### Create Service Principal

1. **Login to Azure CLI:**
   ```bash
   az login
   ```

2. **Get your subscription ID:**
   ```bash
   az account show --query id --output tsv
   ```

3. **Create a service principal with Contributor role:**
   ```bash
   az ad sp create-for-rbac --name "terraform-sp" \
     --role="Contributor" \
     --scopes="/subscriptions/<YOUR_SUBSCRIPTION_ID>"
   ```

   This command will output JSON similar to:
   ```json
   {
     "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
     "displayName": "terraform-sp",
     "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
     "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   }
   ```

4. **Set environment variables for Terraform authentication:**
   ```bash
   export ARM_CLIENT_ID="<appId>"
   export ARM_CLIENT_SECRET="<password>"
   export ARM_SUBSCRIPTION_ID="<YOUR_SUBSCRIPTION_ID>"
   export ARM_TENANT_ID="<tenant>"
   ```

   **Alternative: Create a `.env` file (recommended for persistent use):**
   ```bash
   cat << EOF > .env
   export ARM_CLIENT_ID="<appId>"
   export ARM_CLIENT_SECRET="<password>"
   export ARM_SUBSCRIPTION_ID="<YOUR_SUBSCRIPTION_ID>"
   export ARM_TENANT_ID="<tenant>"
   EOF
   
   # Source the environment variables
   source .env
   ```

5. **Verify the service principal can authenticate:**
   ```bash
   az login --service-principal \
     --username $ARM_CLIENT_ID \
     --password $ARM_CLIENT_SECRET \
     --tenant $ARM_TENANT_ID
   ```

### Security Best Practices

- **Store credentials securely**: Never commit the `.env` file or credentials to version control. Add `.env` to your `.gitignore` file:
  ```bash
  echo ".env" >> .gitignore
  ```
- **Use least privilege**: The Contributor role provides broad permissions. For production, consider creating custom roles with minimal required permissions
- **Rotate credentials regularly**: Service principal secrets should be rotated periodically
- **Use Azure Key Vault**: For production deployments, consider storing service principal credentials in Azure Key Vault


## Project Structure

```
infra/
├── main.tf                 # Root configuration file
├── variables.tf            # Input variables for the root module
├── outputs.tf              # Output values after deployment
├── providers.tf            # Provider configurations
├── backend.tf              # Remote state configuration
├── modules/                # All modular components
│   ├── networking/         # VNet, subnets, NSGs, Bastion
│   ├── compute/            # VM Scale Sets and load balancers
│   ├── database/           # PostgreSQL Flexible Server
│   ├── dns/                # Private DNS Zones
│   └── keyvault/           # Azure Key Vault
└── environments/           # Environment-specific configurations
    └── prod/               # Production environment
```

## Deployment Instructions

### 1. Set up Terraform Backend

Create an Azure Storage Account for storing Terraform state:

```bash
# Login to Azure
az login

# Create Resource Group for Terraform state
az group create --name tfstate-rg --location eastus2

# Create Storage Account
az storage account create --name tfstate<unique_suffix> --resource-group tfstate-rg --sku Standard_LRS --encryption-services blob

# Create Storage Container
az storage container create --name tfstate --account-name tfstate<unique_suffix>
```

### 2. Initialize Terraform

```bash
cd infra
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstate<unique_suffix>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=prod.terraform.tfstate"
```

### 3. One-Step Deployment Approach

Since we're now using Docker Hub instead of Azure Container Registry, we can deploy the entire infrastructure in one step. First, make sure your Docker images are pushed to Docker Hub:

```bash
# Log in to Docker Hub
docker login -u YOUR_DOCKERHUB_USERNAME

# Build and tag your images (Run from the root of the project)
docker build -t YOUR_DOCKERHUB_USERNAME/frontend:latest ./frontend
docker build -t YOUR_DOCKERHUB_USERNAME/backend:latest ./backend

# Push to Docker Hub
docker push YOUR_DOCKERHUB_USERNAME/frontend:latest
docker push YOUR_DOCKERHUB_USERNAME/backend:latest
```

After pushing your images to Docker Hub, deploy the infrastructure with your Docker Hub credentials:

```bash
cd infra
terraform apply \
  -var-file="environments/prod/terraform.tfvars" \
  -var="dockerhub_username=YOUR_DOCKERHUB_USERNAME" \
  -var="dockerhub_password=YOUR_DOCKERHUB_PAT" \
  -var="frontend_image=YOUR_DOCKERHUB_USERNAME/frontend:latest" \
  -var="backend_image=YOUR_DOCKERHUB_USERNAME/backend:latest"
```

This command will:
- Deploy all infrastructure components including compute resources
- Store your Docker Hub Personal Access Token securely in Azure Key Vault
- Configure the VM Scale Sets to pull images from Docker Hub
- Use the specified Docker images for frontend and backend deployments

### 4. Access the Application

After deployment completes, access your application:

- Frontend: Use the Application Gateway public IP address:

  ```bash
  echo "Frontend URL: http://$(terraform output -raw frontend_public_ip)"
  ```

- Backend: Access via internal load balancer (from within the VNet):

  ```bash
  echo "Backend internal endpoint: http://$(terraform output -raw backend_internal_lb_ip):8080"
  ```

- Database: Access via private endpoints from the backend tier:

  ```bash
  echo "PostgreSQL Server: $(terraform output -raw postgres_server_fqdn)"
  echo "PostgreSQL Replica: $(terraform output -raw postgres_replica_name)"
  ```
- SSH into the Bastion host to access the backend and frontend:

  ```bash
  terraform output -raw frontend_ssh_private_key > frontend_key.pem
  terraform output -raw backend_ssh_private_key > backend_key.pem 
  ```

## Infrastructure Management

### Scaling

The VM Scale Sets will automatically scale based on CPU usage. You can modify the scaling rules in the `compute` module.

### Monitoring

The deployment includes Azure Monitor integration. Configure alerts and dashboards in the Azure Portal.

### Security

- All subnets are protected with Network Security Groups
- Application Gateway has WAF enabled
- PostgreSQL is only accessible via private endpoints
- Key Vault stores sensitive information (including Docker Hub credentials)
- SSH access is only available via Bastion Host

## Cleanup

To destroy the infrastructure when no longer needed:

```bash
terraform destroy -auto-approve
```
*If You get a error in the destrucion process rerun the above command again*
## Contributing

Please follow the standard Git workflow:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
