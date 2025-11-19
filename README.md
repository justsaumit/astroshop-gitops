# 🚀 Astroshop GitOps

A GitOps implementation of the OpenTelemetry Demo microservices application deployed on AWS EKS using Terraform and ArgoCD.

[![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-2.1.3-blueviolet?style=flat-square)](https://github.com/open-telemetry/opentelemetry-demo)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32+-326CE5?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange?style=flat-square)](https://argo-cd.readthedocs.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=flat-square&logo=terraform)](https://terraform.io/)

> **Note**: This is my attempt to deploy the [OpenTelemetry Demo](https://github.com/open-telemetry/opentelemetry-demo) (v2.1.3) on AWS using Terraform for infrastructure and ArgoCD for GitOps-based application management. Thanks to all the OpenTelemetry contributors for the amazing demo application!

## 📋 What's Inside

- **Infrastructure**: Terraform modules for AWS VPC and EKS cluster
- **Applications**: Helm charts for 19 microservices
- **GitOps**: ArgoCD ApplicationSet for multi-environment deployments
- **CI/CD**: GitHub Actions workflow for automated deployments
- **Observability**: OpenTelemetry instrumentation across all services

## 🏗️ Architecture

```
AWS Cloud
├── VPC (Terraform)
│   ├── Public Subnets
│   └── Private Subnets
│
└── EKS Cluster (Terraform)
    ├── Dev Environment (astroshop-dev)
    ├── QA Environment (astroshop-qa)
    └── Prod Environment (astroshop-prod)
        │
        └── 19 Microservices
            ├── Frontend (React + Envoy)
            ├── Backend Services (Go, .NET, Python, Java, etc.)
            └── Supporting Services (Kafka, Redis, Flagd)
```

## 📦 Repository Structure

```
.
├── astroshop-helm/              # Helm charts for all services
│   ├── accounting/
│   ├── cart/
│   ├── checkout/
│   ├── productcatalog/
│   └── ... (15 more services)
│
├── astroshop-terraform/         # Infrastructure as Code
│   ├── modules/
│   │   ├── eks/                 # EKS cluster module
│   │   └── vpc/                 # VPC networking module
│   └── main.tf
│
├── argocd/                      # ArgoCD configurations
│   └── argocd-applicationset.yaml
│
└── .github/workflows/           # CI/CD pipelines
    └── build-and-deploy.yaml
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- kubectl, helm, terraform, and argocd CLI installed
- Docker for building images

### 1. Deploy Infrastructure

```bash
cd astroshop-terraform
terraform init
terraform apply -var-file=terraform.tfvars

# Configure kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

### 2. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 3. Deploy Applications

```bash
# Apply ApplicationSet
kubectl apply -f argocd/argocd-applicationset.yaml

# Verify applications
kubectl get applications -n argocd -l app.kubernetes.io/part-of=astroshop
```

### 4. Access the Application

```bash
kubectl port-forward -n astroshop-dev svc/opentelemetry-demo-frontendproxy 8080:8080
# Open http://localhost:8080
```

## 📸 Screenshots

### Homepage - Astronomy Shop
![Homepage](media/pic-sel-25-10-04--01-20-17.png)
*Landing page: "The best telescopes to see the world closer"*

### Product Catalog
![Hot Products](media/pic-sel-25-10-04--01-20-29.png)
*Browse telescopes, binoculars, and astronomy equipment*

### Product Details
![Product Page](media/pic-sel-25-10-04--01-20-50.png)
*Solar System Color Imager - $175.00 with recommendations*

### Shopping Cart
![Shopping Cart](media/pic-sel-25-10-04--01-21-14.png)
*Cart with currency conversion (USD to INR) and shipping calculation*

### Checkout - Address
![Checkout Address](media/pic-sel-25-10-04--01-21-42.png)
*Shipping address form during checkout process*

### Checkout - Payment
![Payment Method](media/pic-sel-25-10-04--01-21-51.png)
*Payment details with credit card form*

### Order Confirmation
![Order Complete](media/pic-sel-25-10-04--01-21-59.png)
*Order confirmation with shipping details*

## 🌍 Multi-Environment Setup

| Environment | Namespace | Sync | Values File |
|------------|-----------|------|-------------|
| **Dev** | `astroshop-dev` | Auto | `values.yaml` |
| **QA** | `astroshop-qa` | Auto | `values-qa.yaml` |
| **Prod** | `astroshop-prod` | Manual | `values-prod.yaml` |

## 🎯 Services

**Frontend**: frontend, frontendproxy  
**Backend**: productcatalog, cart, checkout, payment, shipping, currency, email, recommendation, ad  
**Supporting**: kafka, valkey, flagd, accounting, fraud-detection, imageprovider, quote, loadgenerator

## 🔄 CI/CD Pipeline

GitHub Actions workflow automatically:
1. Builds Docker images on push to main
2. Tags with commit SHA
3. Updates image tags in GitOps repo using `yq`
4. Triggers ArgoCD sync for dev/qa environments

**Required Secrets**: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `GITOPS_PAT`

## 🔧 Useful Commands

```bash
# View all applications
kubectl get applications -n argocd

# Sync specific app
argocd app sync astroshop-productcatalog-dev

# Check application status
argocd app get astroshop-productcatalog-prod

# View pod logs
kubectl logs -n astroshop-dev -l app=productcatalog -f

# Port forward to services
kubectl port-forward -n astroshop-dev svc/<service-name> 8080:8080
```

## 📝 License

MIT License - This is an educational project based on the OpenTelemetry Demo.

## 🙏 Acknowledgments

- [OpenTelemetry Demo](https://github.com/open-telemetry/opentelemetry-demo) team for the excellent microservices demo
- OpenTelemetry, ArgoCD, Kubernetes, and Terraform communities
