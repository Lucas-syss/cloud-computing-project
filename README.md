# Cloud Platform Engineering Project

This project implements a dynamic, multi-tenant Kubernetes infrastructure provisioner using Terraform and Minikube. It creates fully isolated environments for multiple clients (e.g., Airbnb, Nike, McDonalds) with automated application deployment, TLS termination, and ingress routing.

## Architecture

The solution uses a **Single Terraform Project** approach to manage the lifecycle of:
1.  **Kubernetes Clusters**: Provisioned via the `scott-the-programmer/minikube` Terraform provider.
2.  **TLS Certificates**: Generated locally using the `hashicorp/tls` provider.
3.  **Application Deployment**: Odoo, PostgreSQL (StatefulSet), and Ingress are deployed via a robust shell script triggered by `local-exec`.

### Design Decisions

-   **Minikube Provider**: Used to satisfy the requirement of "No manual cluster creation" while keeping the entire lifecycle managed by Terraform.
-   **Dynamic Deployments**: Since the standard Terraform `kubernetes` provider does not support dynamic aliases (iterating over an unknown number of clusters), we use `kubectl` wrapped in a shell script (`scripts/deploy_odoo.sh`). This script dynamically switches contexts to apply manifests to the correct cluster.
-   **Security**: All endpoints are secured with self-signed TLS certificates generated per domain. HTTP-only access is disabled via Ingress annotations.

## Prerequisites

-   **Terraform** >= 1.0
-   **Docker** (Running and accessible)
-   **Minikube**
-   **kubectl**
-   **Make**

## Usage

### 1. Initialize
Initialize Terraform and download providers.
```bash
make init
```

### 2. Provision Infrastructure (Client by Client)
To prevent resource exhaustion and Docker timeouts, we provision one client at a time.
```bash
# 1. Deploy Airbnb (Dev, Prod)
make apply client=airbnb

# 2. Deploy Nike (Dev, QA, Prod)
make apply client=nike

# 3. Deploy McDonalds (Dev, QA, Beta, Prod)
make apply client=mcdonalds
```
*Note: Terraform is configured with `-parallelism=1` to ensure sequential, stable cluster creation.*

### 3. Update Hosts
Map the dynamic domains to the cluster IPs in your `/etc/hosts` file.
```bash
make update-hosts
```
*Note: This script uses a Docker-safe method to update hosts inside containers/Codespaces.*

### 4. Validate
Verify that all endpoints are reachable and serving the application correctly.
```bash
make validate
```
**Success Criteria:** You should see `HTTP 303` (Redirect to Login) and a valid `session_id` cookie for every environment.

### 5. Destroy
Tear down all clusters and clean up resources to stop resource consumption.
```bash
make destroy
```

## Project Structure

-   `main.tf`: Core Terraform configuration (Clusters, Certs, Deployment triggers).
-   `templates/`: Kubernetes YAML templates (Odoo Deployment, PVC, Service, Ingress).
-   `scripts/`: Automation scripts.
    -   `deploy_odoo.sh`: Handles context switching, secrets, and manifest application.
    -   `update_hosts.sh`: Scans all 9 clusters and updates `/etc/hosts` safely.
    -   `validate.sh`: Curl loop to test connectivity.
-   `Makefile`: Shortcut commands for the engineering workflow.

## Engineering Challenges & Solutions

This project overcame several specific technical hurdles regarding Terraform and Kubernetes interop:

### 1. The "Dynamic Provider" Limitation
* **The Issue:** Terraform requires Kubernetes provider configurations (host, certs) to be known at *plan* time. You cannot iterate a `kubernetes` provider over a list of clusters that don't exist yet.
* **The Solution:** We decoupled the *Infrastructure* (Minikube) from the *Application* (K8s manifests). We use `null_resource` with a `local-exec` provisioner to call a shell script. The script uses `kubectl` directly, which allows us to dynamically switch contexts (`kubectl config use-context`) at runtime after the clusters are created.

### 2. Resource Contention & State Locking
* **The Issue:** Spinning up 9 Kubernetes clusters simultaneously on a single machine caused Docker API timeouts and network instability. Additionally, modifying script files during a `terraform apply` caused "Inconsistent Result" errors regarding file checksums.
* **The Solution:**
    1.  Implemented a **Segmented Apply Workflow** (Client-by-Client) using Terraform variables (`-var client=...`).
    2.  Forced **Sequential Execution** using `-parallelism=1`.
    3.  Stabilized file inputs to ensure checksums remain consistent during the plan/apply phases.

### 3. Ingress Controller "Race Condition"
* **The Issue:** After a cluster starts, the NGINX Ingress Controller takes time to assign an IP address. Deploying the app immediately resulted in "Address not found" errors.
* **The Solution:** Added a `wait` loop in the deployment script that polls the Ingress controller status (`kubectl get ingress`) and blocks execution until an IP address is officially assigned before proceeding.

### 4. Container File System Restrictions
* **The Issue:** Inside GitHub Codespaces (Docker), `/etc/hosts` is a mounted file that cannot be moved or renamed, causing `sed -i` commands to fail with "Device or resource busy".
* **The Solution:** Wrote a specialized `update_hosts.sh` that copies the content to a temp file, modifies it, and uses `cat` redirection (`cat /tmp/hosts > /etc/hosts`) to overwrite the content in place without changing the file inode.
