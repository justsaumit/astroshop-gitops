# Detailed Breakdown of Terraform Configuration

## 0. BACKEND (3 resources) - State Management

### 1. **S3 Bucket: `astroshop-terraform-state-647242312368`**
**Purpose:** Remote state storage
- Stores your Terraform state file (tracks all infrastructure you create)
- Named with your AWS account ID to ensure global uniqueness
- `prevent_destroy = true` prevents accidental deletion

**Why it matters:** Without this, Terraform state would be stored locally, making it:
- Hard to collaborate (other team members can't see changes)
- Risky (if your laptop dies, you lose track of infrastructure)

### 2. **S3 Bucket Versioning**
**Purpose:** State file backup and rollback
- Keeps version history of your state file
- Lets you recover from mistakes: `terraform state pull <version>`
- If you accidentally corrupt state, you can restore from an older version

### 3. **S3 Bucket Server-Side Encryption (AES256)**
**Purpose:** Security
- Encrypts state file at rest
- Your state contains sensitive info (passwords, API keys, database credentials)
- AES256 is AWS-managed encryption (free, automatic)

---

