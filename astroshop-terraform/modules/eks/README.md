# Module 2: EKS (Elastic Kubernetes Service) - 8 resources

EKS is a **managed Kubernetes service on AWS**. AWS handles the control plane, you manage the worker nodes.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                   AWS Control Plane                          │
│         (Managed by AWS - You don't manage this)             │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Kubernetes API Server / etcd / Scheduler / etc.       │  │
│  │  Handles cluster orchestration & state management      │  │
│  └────────────────────────────────────────────────────────┘  │
│                         ↓ (HTTPS)                            │
└──────────────────────────────────────────────────────────────┘
           ↓
┌────────────────────────────────────────────────────────────┐
│                    Your VPC (Private)                      │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Private Subnets (3 AZs)                 │  │
│  │                                                      │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │  Worker     │  │  Worker     │  │  Worker     │   │  │
│  │  │  Node 1     │  │  Node 2     │  │  Node 3     │   │  │
│  │  │ 10.0.1.x    │  │ 10.0.2.x    │  │ 10.0.3.x    │   │  │
│  │  │             │  │             │  │             │   │  │
│  │  │ Pods        │  │ Pods        │  │ Pods        │   │  │
│  │  │ Container   │  │ Container   │  │ Container   │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  │              (Auto-scales up to 3 nodes)             │  │
│  │                                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Public Subnets (3 AZs)                  │  │
│  │                                                      │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │  Kubernetes Load Balancer Service            │    │  │
│  │  │  (External traffic enters here)              │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Core Components

### **1. EKS Cluster: `astroshop-eks-cluster`**

**Purpose:** The Kubernetes cluster control plane endpoint

**What it does:**
- Manages your container orchestration
- Stores cluster state in etcd database
- Schedules pods on worker nodes
- Handles health checks and auto-recovery
- Exposes Kubernetes API for `kubectl` commands

**Configuration:**
```
Name:              astroshop-eks-cluster
Kubernetes Ver:    1.32
VPC:               10.0.0.0/16 (from VPC module)
Subnets:           Private subnets only (10.0.1-3.0/24)
Logging:           API, Audit, Authenticator, ControllerManager, Scheduler
Endpoints:         Private & Public access enabled
```

**When you deploy:**
```bash
kubectl get nodes  # Queries API through endpoint
kubectl apply -f app.yaml  # Control plane schedules on nodes
kubectl logs pod-name  # Retrieves logs from pod
```

**Cost:** ~$0.10/hour (~$73/month)

---

### **2. Cluster IAM Role: `astroshop-eks-cluster-cluster-role`**

**Purpose:** Permissions for EKS control plane to manage AWS resources

**What it allows the control plane to:**
- Create/modify security groups for node communication
- Attach/detach network interfaces (ENI) to worker nodes
- Create Application Load Balancers for Kubernetes services
- Write logs to CloudWatch Logs
- Manage Auto Scaling groups for node groups
- Describe EC2 resources

**Trust Policy:**
```json
{
  "Service": "eks.amazonaws.com"
}
```

**What it allows:**
- Only the EKS service can Create/modify security groups
- Attach network interfaces to nodes
- Create load balancers for services
- Manage cluster infrastructure

**Attached Policy:**
- `AmazonEKSClusterPolicy` - Full EKS permissions

---

### **3. Cluster Policy Attachment**

Connects the `AmazonEKSClusterPolicy` to the cluster role.

**Example use case:**
```
You: kubectl create service type=LoadBalancer
           ↓
Control Plane (uses cluster role)
           ↓
    Creates Application Load Balancer in public subnets
           ↓
Attaches network interfaces to nodes
           ↓
Updates security groups
           ↓
    External traffic reaches your pods ✓
```

---

**Policy includes permissions for:**
- Creating/modifying load balancers
- Managing security groups
- EC2 operations
- CloudWatch Logs

---

### **4. Node IAM Role: `astroshop-eks-cluster-node-role`**

Permissions for worker nodes to access AWS resources.

**Trust Policy:**
```json
{
  "Service": "ec2.amazonaws.com"
}
```

**What it allows:**
- Pull container images from ECR
- Write logs to CloudWatch
- Join the EKS cluster
- Communicate with control plane
- Access EC2 metadata service

---

### **5. Node Policy Attachments (3 Policies)**

**Policy 1: AmazonEKSWorkerNodePolicy**
- Basic node permissions
- EC2 and SSM access
- Node-to-control-plane communication

**Policy 2: AmazonEKS_CNI_Policy**
- Network interface management
- Pod networking
- IP address assignment to pods

**Policy 3: AmazonEC2ContainerRegistryReadOnly**
- Pull Docker images from ECR
- Container image authentication

**Example flow:**
```
Pod deployed on node
         ↓
Node assumes node role
         ↓
Runs: docker pull 123456789.dkr.ecr.ap-south-1.amazonaws.com/myapp:latest
         ↓
Uses ECR policy to authenticate
         ↓
Pulls image successfully ✓
```

---

### **6. Node IAM Instance Profile: `astroshop-eks-cluster-node-profile`**

**Purpose:** Bridges IAM role to EC2 instance metadata

**Why is it needed?**
- EC2 instances can't directly use IAM roles
- Instance profiles attach IAM roles to EC2 instances
- Allows running containers to access AWS APIs

**How it works:**
```
EC2 Instance (Worker Node)
         ↓
   Instance Profile
         ↓
   Node IAM Role
         ↓
   Pod can call: AWS SDK (boto3, SDK, etc.)
         ↓
   Access ECR / S3 / DynamoDB / etc. ✓
```

---

### **7. Node Security Group (Auto-created)**

**Purpose:** Firewall for worker nodes

**Ingress Rules:**
```
Port 1025-65535 (TCP):
  From: Cluster Security Group
  Purpose: Control plane ↔ node communication
  
Port 443 (HTTPS):
  From: Cluster Security Group
  Purpose: API server ↔ node communication

Port 0-65535 (All):
  From: Same security group (node-to-node)
  Purpose: Pod-to-pod communication across nodes
```

**Egress Rules:**
```
All traffic to 0.0.0.0/0 (internet)
Purpose: 
  - Pull container images
  - Download package managers
  - Access external APIs
```

**Example traffic flows:**
```
1. Control Plane → Node (schedule pod)
   Through: Port 10250 (Kubelet API)
            ↓
   Node Security Group allows
            ↓
   Pod scheduled ✓

2. Pod-1 → Pod-2 (cross-node communication)
   Through: Pod's ephemeral port
            ↓
   Same security group allows
            ↓
   Pod-to-pod network ✓

3. Pod → Docker Hub (pull image)
   Through: Port 443 (HTTPS)
            ↓
   NAT Gateway (from VPC module)
            ↓
   Internet ✓
```

---

### **8. Worker Node Group: `general`**

**Purpose:** Fleet of EC2 instances running your containers

**Configuration:**
```
Name:                 astroshop-eks-cluster-general
Instance Type:        m7i-flex.large (2 vCPU, 8GB RAM)
Capacity Type:        ON_DEMAND (not Spot)
Desired Size:         2 nodes
Min Size:             1 node
Max Size:             3 nodes
Kubernetes Version:   1.32 (matches cluster)
Subnets:              Private only (10.0.1-3.0/24)
Security Group:       Node Security Group
```

**What gets created:**
```
2 EC2 Instances (m7i-flex.large)
         ↓
   Joined to EKS cluster
         ↓
   Each has:
   - Private IP (10.0.1.x / 10.0.2.x)
   - Node IAM role attached
   - Docker daemon running
   - kubelet service running
   - CNI plugin for pod networking
```

**Auto-scaling:**
```
Current load: 2 replicas → fits on 2 nodes
Load increases: 5 replicas needed
         ↓
Auto Scaler detects insufficient resources
         ↓
Launches 3rd node (up to max_size: 3)
         ↓
All pods scheduled ✓
```

**Cost:** ~$0.28/hour per m7i-flex.large
- 2 nodes × $0.28 = $0.56/hour (~$400/month)

**Example: Pod Scheduling**
```
You: kubectl apply -f deployment.yaml (3 pod replicas)
         ↓
Control Plane:
  - Pod-1 → Node 1 (available resources)
  - Pod-2 → Node 2 (available resources)
  - Pod-3 → Can't fit on existing nodes
         ↓
  Node Group Auto Scaler detects this
         ↓
 Launches 3rd node (up to max_size)
         ↓
  Pod-3 scheduled on Node-3
         ↓
All 3 pods running ✓
```

---

## Complete Traffic Flow

```
External User
     ↓
Internet Gateway (from VPC module)
     ↓
Load Balancer (in public subnet)
     ↓
Private Subnet → Worker Nodes
     ↓
Pods receive & process request
     ↓
Response back through same path
     ↓
External User gets response ✓
```

---

## Resource Summary

| Resource | Count | Purpose | Cost |
|----------|-------|---------|------|
| EKS Cluster | 1 | Control plane | $0.10/hr (~$73/mo) |
| Cluster IAM Role | 1 | Control plane permissions | Free |
| Cluster Policy Attachment | 1 | Attach policies to role | Free |
| Node IAM Role | 1 | Worker node permissions | Free |
| Node Policy Attachments | 3 | Attach policies to nodes | Free |
| Node Group | 1 | Worker fleet (managed) | Free |
| Worker Nodes (EC2) | 2-3 | Run pods | $0.28/hr each |

**Total Monthly Cost (Minimum):**
```
EKS Cluster:        $73
2 × m7i-flex.large: $400 (~0.28 × 730 hours × 2)
─────────────────────
Total:              ~$473/month (ap-south-1)
```

---

## Common Operations

### Add more capacity
Edit `modules/eks/variables.tf` or pass as variable:
```bash
terraform apply -var="node_groups={general={instance_types=[\"m7i-flex.large\"],capacity_type=\"ON_DEMAND\",scaling_config={desired_size=3,max_size=5,min_size=1}}}"
```

### Change node size
Edit desired_size in root `variables.tf`:
```hcl
variable "node_groups" {
  default = {
    general = {
      instance_types = ["m7i-flex.large"]
      capacity_type  = "ON_DEMAND"
      scaling_config = {
        desired_size = 3
        max_size     = 5
        min_size     = 1
      }
    }
  }
}
```

### View cluster info
```bash
kubectl cluster-info
```

### Check pod status
```bash
kubectl get pods -A
```

### View Cluster Logs
```bash
aws logs tail /aws/eks/astroshop-eks-cluster/cluster
  ↓
Shows all control plane activity
```

---

## Architecture Decisions Made

| Decision | Why |
|----------|-----|
| Private subnets only | Security: nodes can't be reached from internet |
| 3 AZs (multi-AZ) | High availability: cluster survives AZ failure |
| ON_DEMAND capacity | Reliability: Spot can be interrupted |
| m7i-flex.large | Balance of CPU/memory for typical workloads |
| Min size 1, Max size 3 | Cost control while allowing scaling |
| Version 1.32 | Latest stable Kubernetes version |

---