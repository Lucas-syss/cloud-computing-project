# Cloud Platform Engineering Project

This project implements a dynamic Kubernetes infrastructure provisioner using Terraform and Minikube. It supports multiple clients and environments with fully isolated clusters and applications.

## Architecture

The solution uses a **Single Terraform Project** approach to manage the lifecycle of:
1.  **Kubernetes Clusters**: Provisioned via the `scott-the-programmer/minikube` Terraform provider.
2.  **TLS Certificates**: Generated locally using the `hashicorp/tls` provider.
3.  **Application Deployment**: Odoo, PostgreSQL (StatefulSet), and Ingress are deployed via a robust shell script triggered by `local-exec`.

### Design Decisions

-   **Minikube Provider**: Used to satisfy the requirement of "No manual cluster creation" while keeping the entire lifecycle managed by Terraform.
-   **Dynamic Deployments**: Since the standard `kubernetes` provider does not support dynamic aliases (needed for N clusters), we use `kubectl` wrapped in a shell script (`scripts/deploy_odoo.sh`) to apply manifests to the correct context. This ensures the project remains scalable (loops over clients) without duplicating resource blocks.
-   **Security**: All endpoints are secured with self-signed TLS certificates generated per domain. HTTP-only access is disabled via Ingress annotations.

## Prerequisites

-   **Terraform** >= 1.0
-   **Docker** (Running and accessible)
-   **Minikube**
-   **kubectl**
-   **jq** (Used in scripts)
-   **gettext-base** (for `envsubst`)

## Usage

### 1. Initialize
Initialize Terraform and download providers.
```bash
make init
```

### 2. Provision Infrastructure
Create clusters, generate network configurations, and deploy applications.
```bash
make apply
```
*Note: This process may take several minutes as it spins up multiple Minikube instances.*

### 3. Update Hosts
Map the dynamic domains to Minikube IPs in your `/etc/hosts` file.
```bash
make update-hosts
```
*Note: Requires sudo/root permissions inside the container.*

### 4. Validate
Verify that all endpoints are reachable and serving the application.
```bash
make validate
```
This script curls each defined domain (e.g., `https://odoo.dev.airbnb.local`) and reports the status.

### 5. Destroy
Tear down all clusters and clean up resources.
```bash
make destroy
```

## Configuration

### Adding Clients or Environments
All configuration is data-driven. To add a new client or environment, simply edit the `clients` variable in `main.tf`.

**Example:**
```hcl
variable "clients" {
  default = {
    "airbnb" = {
      environments = ["dev", "prod"]
    }
    # New Client
    "tesla" = {
      environments = ["dev", "staging", "prod"]
    }
  }
}
```
Re-run `make apply` to provision the new resources. No other code changes are required.

## Project Structure

-   `main.tf`: Core Terraform configuration (Clusters, Certs, Deployment triggers).
-   `templates/`: Kubernetes YAML templates (Odoo Stack).
-   `scripts/`: Automation scripts.
    -   `deploy_odoo.sh`: Context switching, secret creation, manifest application.
    -   `update_hosts.sh`: Updates `/etc/hosts` with Minikube IPs.
    -   `validate.sh`: automated testing of endpoints.
-   `Makefile`: Shortcut commands.