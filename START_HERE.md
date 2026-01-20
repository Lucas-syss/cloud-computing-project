# Final Project – Multi-Client Kubernetes Provisioning with Terraform

## Context

You are part of a Cloud Platform Engineering team responsible for delivering Kubernetes infrastructure and applications to multiple enterprise clients.

All infrastructure must be provisioned using a single Terraform project, capable of dynamically creating Kubernetes clusters, configuring networking and deploying applications according to each client’s requirements.

Development and validation are performed inside a DevContainer, simulating a controlled and reproducible engineering environment.

## Scenario

You must provision Kubernetes infrastructure for three clients, each with multiple environments.

### Clients and Environments

| Client     | Environments           |
|------------|------------------------|
| AirBnB     | Dev, Prod              |
| Nike       | Dev, QA, Prod          |
| McDonalds  | Dev, QA, Beta, Prod    |

Each environment represents an independent runtime context and must have its own Kubernetes cluster.

## Functional Requirements

For every client and environment, the platform must provide:

- A dedicated Kubernetes cluster (one cluster per environment)
- A publicly accessible Odoo application
- Secure access over HTTPS
- Full isolation between:
  - Clients
  - Environments
  - Application and database workloads

## Technical Requirements

### 1. Terraform Project Design

You must implement a single Terraform project that:

- Treats clients and environments as data, not hardcoded logic
- Avoids duplication of Terraform resources
- Allows adding new clients or environments by changing variables only

No Terraform resource blocks should need modification when clients or environments change.

### 2. Kubernetes Cluster Provisioning

- Minikube is the required Kubernetes provider
- Each environment must have its own Minikube cluster
- All clusters must be created and managed by Terraform
- Terraform must:
  - Control cluster lifecycle
  - Configure access via kubeconfig
  - Manage Kubernetes resources using the Kubernetes provider

Manual cluster creation outside Terraform is not allowed.

### 3. Odoo Application Deployment

For each Kubernetes cluster, Terraform must deploy:

- An Odoo application
- A Kubernetes Namespace following this pattern: client-environment
- An Odoo application Deployment
- A Kubernetes Service for Odoo
- A StatefulSet for the Odoo database with persistent storage
- A Service for the database
- An Ingress exposing the application publicly over HTTPS

Each deployment must be:

- Fully isolated
- Configurable per environment
- Deterministically named

### 4. Domain Naming and DevContainer Validation

All application access must follow this mandatory domain pattern:

odoo.ENV.CLIENT.local

Examples:
- odoo.dev.nike.local
- odoo.qa.mcdonalds.local
- odoo.prod.airbnb.local

### Validation Process

Since development occurs inside a DevContainer, validation will be performed by executing:

curl https://DOMAIN

For each client and environment.

To support this:

- The student must edit /etc/hosts inside the DevContainer (via scripts)
- All domains must resolve correctly to the appropriate cluster ingress
- Each domain must route traffic to the correct Odoo instance and its corresponding database

### 5. HTTPS and TLS Certificates

All applications must be exposed over HTTPS.

Terraform must be responsible for:

- Creating TLS certificates for each domain
- Managing Kubernetes Secret resources containing certificates
- Binding certificates to the Ingress resources

Self-signed certificates are acceptable.

HTTP-only access is not allowed.

### 6. Automation and Developer Experience

The use of automation is strongly encouraged:

- Makefile usage (for example: make apply, make destroy, make validate)
- Shell scripts to:
  - Bootstrap Minikube clusters
  - Update /etc/hosts
  - Validate endpoints

### 7. Constraints

- CI/CD pipelines are out of scope
- Helm is not required

Code readability, structure and scalability are critical.

## Deliverables

The final submission must include:

- A single Terraform project
- A README.md explaining:
  - Architecture and design decisions
  - How to add a new client
  - How to add a new environment
  - How to validate deployments using curl
- Terraform code that:
  - Provisions all Kubernetes clusters
  - Deploys Odoo to every environment
  - Configures HTTPS access
- Automation assets:
  - Makefiles
  - Shell scripts

All infrastructure must be created using a single terraform apply.

## Evaluation Criteria (20 Points)

| Criteria | Description | Points |
|---------|------------|--------|
| Dynamic Terraform | Correct modelling of clients and environments using maps, loops and locals | 6 |
| Cluster Provisioning with Minikube | Terraform-managed lifecycle of all Kubernetes clusters | 4 |
| Kubernetes Application Deployment | Correct namespaces, deployments, statefulsets, services and ingress per environment | 3 |
| HTTPS and TLS Configuration | Proper certificate creation and secure ingress exposure | 3 |
| Automation and DX | Makefiles and scripts improving usability and reproducibility | 2 |
| Documentation Quality | Clear, professional and complete README | 1 |
| Naming and Consistency | Predictable, readable and scalable naming conventions | 1 |
| Total |  | 20 |
