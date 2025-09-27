# Module 1: VPC (Virtual Private Cloud) - 24 resources

VPC is a logically **isolated network in AWS**. Everything inside needs to communicate through VPC.

### **Core Network Infrastructure:**

#### **1. VPC: `astroshop-eks-cluster-vpc`**
```
CIDR: 10.0.0.0/16 (65,536 IP addresses available)
```
**Purpose:** Main network container
- Private network isolated from the internet
- All your resources (EKS cluster, databases, etc.) live here
- DNS enabled for internal service discovery
- Cannot directly reach outside without routing rules

**Visual:**
```
┌─────────────────────────────────────────┐
│  VPC: 10.0.0.0/16                       │
│  (Your entire isolated network)         │
│                                         │
│  ┌──────────┐         ┌──────────┐      │
│  │ Subnet   │         │ Subnet   │  ... │
│  │ 10.0.x/24│         │ 10.0.x/24│      │
│  └──────────┘         └──────────┘      │
└─────────────────────────────────────────┘
```

---

### **Subnets: Dividing the VPC into Smaller Zones**

#### **3 Private Subnets** (for EKS worker nodes)
```
- private-1: 10.0.1.0/24   (256 IPs) → AZ: ap-south-1a
- private-2: 10.0.2.0/24   (256 IPs) → AZ: ap-south-1b
- private-3: 10.0.3.0/24   (256 IPs) → AZ: ap-south-1c
```

**Purpose:** 
- Host your EKS worker nodes (Kubernetes pods run here)
- No public internet access (secure)
- Instances get private IPs: `10.0.1.x`, `10.0.2.x`, etc.
- Cannot be reached from the internet directly
- Have tags for Kubernetes load balancer discovery

**Why 3 subnets in 3 AZs?**
- **High Availability**: If one AZ goes down, your cluster survives
- **Load Distribution**: Spreads traffic across zones
- **Cost-effective redundancy**: No extra cost for multi-AZ

#### **3 Public Subnets** (for load balancers/NAT)
```
- public-1: 10.0.4.0/24   (256 IPs) → AZ: ap-south-1a
- public-2: 10.0.5.0/24   (256 IPs) → AZ: ap-south-1b
- public-3: 10.0.6.0/24   (256 IPs) → AZ: ap-south-1c
```

**Purpose:**
- Host internet-facing load balancers
- Auto-assign public IPs to resources (`map_public_ip_on_launch = true`)
- Can reach the internet directly
- Will hold NAT Gateways for private subnets

---

### **Internet Connectivity:**

#### **1. Internet Gateway (IGW): `astroshop-eks-cluster-igw`**
**Purpose:** Gateway between your VPC and the internet

**How it works:**
```
Internet
   ↓
Internet Gateway
   ↓
Public Subnets (10.0.4-6.0/24)
   ↓
Load Balancers / Public Resources
```

**Examples:**
- External traffic reaches your Kubernetes service (LoadBalancer type)
- Users access your web application through the IGW

---

#### **3 NAT Gateways** (one per AZ)
**Purpose:** Allow private resources to reach the internet (one-way)

**How it works:**
```
Private Subnet (10.0.1.0/24)
       ↓
   Pod needs to download Docker image from DockerHub
       ↓
   NAT Gateway (in public subnet)
       ↓
   Internet Gateway
       ↓
   DockerHub (internet)
       ↓
   Response comes back through NAT
       ↓
   Pod receives Docker image ✓
```

**Key:** Response traffic automatically finds way back to private subnet

**Cost Warning:** USD 0.45/day per NAT Gateway in ap-south-1 = approx $40/month for 3

---

#### **3 Elastic IPs (EIPs)** for NAT Gateways
**Purpose:** Static public IP for each NAT Gateway

**Why needed?**
- When private subnet makes request through NAT, it needs a public IP
- EIP ensures it's always the same IP (important for whitelisting)
- If NAT Gateway restarts, EIP stays attached

**Example flow:**
```
Pod (10.0.1.10) → NAT Gateway → Internet (appears as EIP: x.y.z.w)
```

---

### **Routing: How Traffic Flows**

#### **1 Public Route Table**
**Purpose:** Route traffic from public subnets to internet

**Route Rule:**
```
Destination: 0.0.0.0/0 (everything)  →  Target: Internet Gateway
```

**In English:** Any traffic from public subnets destined for outside VPC goes through IGW

**Example:**
```
Client request: 203.0.113.50 (internet) → Your Load Balancer (10.0.4.x)
             ↓
          IGW
             ↓
        Public Subnet
             ↓
        Load Balancer receives it ✓
```

---

#### **3 Private Route Tables** (one per AZ)
**Purpose:** Route traffic from private subnets through NAT

**Route Rule:**
```
Destination: 0.0.0.0/0 (everything)  →  Target: NAT Gateway (in same AZ)
```

**In English:** Any traffic from private subnets destined for outside VPC goes through NAT

**Why one per AZ?**
- **Redundancy**: If NAT Gateway in AZ-a fails, only AZ-a is affected
- **Performance**: Traffic stays within same AZ (lower latency)
- **Cost**: You pay per NAT, so this is necessary

**Example:**
```
Pod in private-1 (10.0.1.x) needs to reach DockerHub
                ↓
         Private Route Table-1
                ↓
      NAT Gateway-1 (in public-1)
                ↓
         Internet Gateway
                ↓
         DockerHub (internet)
```

---

#### **6 Route Table Associations**
**Purpose:** Connect subnets to their route tables

**Mappings:**
```
Public Subnets (3):
  - public-1 → Public Route Table
  - public-2 → Public Route Table
  - public-3 → Public Route Table

Private Subnets (3):
  - private-1 → Private Route Table-1
  - private-2 → Private Route Table-2
  - private-3 → Private Route Table-3
```

**Without these:** Traffic wouldn't know where to go!

---

## COMPLETE TRAFFIC FLOW DIAGRAM

```
┌────────────────────────────────────────────────────────────┐
│                      INTERNET                              │
└───────────────────────┬────────────────────────────────────┘
                        │
                   IGW (Internet Gateway)
                        │
        ┌───────────────┴────────────────┐
        │                                │
   ┌────▼─────┐                    ┌─────▼──────┐
   │ Public   │                    │  Private   │
   │ Subnet   │ (Load Balancers)   │  Subnet    │
   │10.0.4/24 │◄──────────────────►│ 10.0.1/24  │
   └────┬─────┘   (internal)       │(EKS Nodes) │
        │                          └─────┬──────┘
        │ (external traffic)             │
        │                                │ (needs internet)
        │                         NAT Gateway
        │                                │
        └────────────────┬───────────────┘
                         │
                    IGW (outbound)
                         │
                    INTERNET
```

---

## Summary Table

| Component | Count | Purpose | Cost |
|-----------|-------|---------|------|
| VPC | 1 | Network container | Free |
| Public Subnets | 3 | Load balancers/internet access | Free |
| Private Subnets | 3 | EKS nodes (secure) | Free |
| Internet Gateway | 1 | Internet connectivity | Free |
| NAT Gateways | 3 | Private → Internet | $0.45/day each |
| Elastic IPs | 3 | Static IP for NAT | Free (when attached) |
| Route Tables | 4 | Traffic routing | Free |

**Monthly VPC Cost:** ~$40 (NAT Gateways only) + data processing

---

## When EKS Deploys (Later)

Your worker nodes will:
```
1. Launch in private subnets (10.0.1-3.0/24)
2. Download container images via NAT → IGW → Internet
3. Receive external traffic via Load Balancer in public subnet
4. Respond back through same path
```