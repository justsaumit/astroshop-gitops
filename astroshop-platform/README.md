# Astroshop ArgoCD ApplicationSet

This repository contains the ArgoCD ApplicationSet configuration for deploying the Astroshop microservices application across multiple environments (Dev, QA, and Production).

## Overview

The ApplicationSet automatically generates and manages ArgoCD Applications for all Astroshop services across three environments, creating a total of **57 applications** (19 services × 3 environments).

### Services Deployed

The following microservices are deployed:

- `accounting`
- `ad`
- `cart`
- `checkout`
- `currency`
- `email`
- `flagd`
- `fraud-detection`
- `frontend`
- `frontendproxy`
- `imageprovider`
- `kafka`
- `loadgenerator`
- `payment`
- `productcatalog`
- `quote`
- `recommendation`
- `shipping`
- `valkey`

## Architecture

### Environment Configuration

| Environment | Namespace | Values File | Sync Policy | Purpose |
|------------|-----------|-------------|-------------|---------|
| **Dev** | `astroshop-dev` | `values.yaml` | Automated | Development and testing |
| **QA** | `astroshop-qa` | `values-qa.yaml` | Automated | Quality assurance and staging |
| **Prod** | `astroshop-prod` | `values-prod.yaml` | Manual | Production workloads |

### Repository Structure

```
astroshop-helm/
├── accounting/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-qa.yaml
│   ├── values-prod.yaml
│   └── templates/
├── ad/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-qa.yaml
│   └── values-prod.yaml
├── ...
└── [other services]
```

## Prerequisites

- ArgoCD installed and running (v2.8+)
- Kubernetes cluster with appropriate RBAC permissions
- Access to GitOps repository: `https://git.draconyan.xyz/Astroshop-Gitops`
- kubectl CLI configured

## Installation

### 1. Apply the ApplicationSet

```bash
kubectl apply -f argocd-applicationset.yaml
```

### 2. Verify ApplicationSet Creation

```bash
# Check ApplicationSet
kubectl get applicationset -n argocd astroshop-services

# View all generated applications
kubectl get applications -n argocd -l app.kubernetes.io/part-of=astroshop
```

### 3. Check Application Status

```bash
# View applications by environment
kubectl get applications -n argocd -l environment=dev
kubectl get applications -n argocd -l environment=qa
kubectl get applications -n argocd -l environment=prod

# Get detailed status of a specific application
kubectl describe application astroshop-productcatalog-dev -n argocd
```

## Configuration

### AppProjects

Three dedicated ArgoCD Projects are created:

#### astroshop-dev
- **Purpose**: Development environment
- **Sync**: Fully automated
- **Allowed Resources**: All namespaced resources
- **Destination**: `astroshop-dev` namespace

#### astroshop-qa
- **Purpose**: QA/Staging environment
- **Sync**: Fully automated
- **Allowed Resources**: All namespaced resources
- **Destination**: `astroshop-qa` namespace

#### astroshop-prod
- **Purpose**: Production environment
- **Sync**: Manual approval required
- **Sync Window**: Weekdays 10:00-18:00 only
- **Allowed Resources**: All namespaced resources
- **Destination**: `astroshop-prod` namespace

### Sync Policies

#### Dev & QA Environments
```yaml
syncPolicy:
  automated:
    prune: true        # Auto-delete resources not in Git
    selfHeal: true     # Auto-sync on drift detection
  syncOptions:
    - CreateNamespace=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

#### Production Environment
```yaml
syncPolicy:
  automated:
    prune: false       # Manual deletion required
    selfHeal: false    # Manual sync required
```

## Operations

### Viewing Applications in ArgoCD UI

1. Access ArgoCD UI: `https://argocd.yourdomain.com`
2. Filter by labels:
   - `environment=dev|qa|prod`
   - `app.kubernetes.io/part-of=astroshop`
   - `service=<service-name>`

### Manual Sync (Production)

```bash
# Sync a specific production application
argocd app sync astroshop-productcatalog-prod

# Sync all production applications
argocd app sync -l environment=prod

# Sync with dry-run
argocd app sync astroshop-productcatalog-prod --dry-run
```

### Refresh Applications

```bash
# Hard refresh (force Git pull)
argocd app get astroshop-productcatalog-dev --hard-refresh

# Refresh all dev applications
argocd app get -l environment=dev --refresh
```

### Rollback

```bash
# List application history
argocd app history astroshop-productcatalog-prod

# Rollback to specific revision
argocd app rollback astroshop-productcatalog-prod <revision-id>
```

## Customization

### Adding a New Service

1. Create Helm chart in `astroshop-helm/<service-name>/`
2. Add service to the ApplicationSet generator list:

```yaml
- list:
    elements:
      - service: newservice
        port: 8080
```

3. Commit and push changes
4. ApplicationSet will automatically create 3 new applications

### Modifying Environment Configuration

Edit the environment generator in the ApplicationSet:

```yaml
- list:
    elements:
      - env: dev
        namespace: astroshop-dev
        valuesFile: values.yaml
        syncPolicy: automated
        # ... modify settings
```

### Changing Sync Windows (Production)

Edit the `astroshop-prod` AppProject:

```yaml
syncWindows:
  - kind: allow
    schedule: '0 10-18 * * 1-5'  # Cron format
    duration: 8h
    manualSync: true
```

## Monitoring and Notifications

### Slack Notifications

The ApplicationSet includes Slack notification annotations:

```yaml
annotations:
  notifications.argoproj.io/subscribe.on-sync-succeeded.slack: astroshop-deployments
  notifications.argoproj.io/subscribe.on-sync-failed.slack: astroshop-alerts
```

**Setup Required:**
1. Configure ArgoCD Notifications controller
2. Update channel names in the ApplicationSet
3. Configure Slack integration in ArgoCD

### Health Checks

Applications inherit health checks from their Helm charts. Monitor via:

```bash
# Check application health
argocd app get astroshop-productcatalog-prod

# Check sync status
argocd app list -l environment=prod
```

## Troubleshooting

### Application Not Syncing

```bash
# Check application details
kubectl describe application astroshop-<service>-<env> -n argocd

# Check sync status
argocd app get astroshop-<service>-<env>

# View sync errors
argocd app sync astroshop-<service>-<env> --dry-run
```

### ApplicationSet Not Generating Apps

```bash
# Check ApplicationSet logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Verify ApplicationSet status
kubectl get applicationset astroshop-services -n argocd -o yaml
```

### Git Repository Access Issues

```bash
# Test repository connectivity
argocd repo get https://git.draconyan.xyz/Astroshop-Gitops

# Add repository if missing
argocd repo add https://git.draconyan.xyz/Astroshop-Gitops \
  --username <username> \
  --password <token>
```

### Permission Issues

```bash
# Check AppProject permissions
kubectl get appproject astroshop-dev -n argocd -o yaml

# Verify RBAC
kubectl auth can-i create deployment --namespace=astroshop-dev
```

## Labels and Selectors

All applications are labeled with:

| Label | Description | Example |
|-------|-------------|---------|
| `app.kubernetes.io/name` | Service name | `productcatalog` |
| `app.kubernetes.io/instance` | Environment instance | `astroshop-dev` |
| `app.kubernetes.io/part-of` | Application suite | `astroshop` |
| `environment` | Environment name | `prod` |
| `service` | Service identifier | `productcatalog` |

### Useful Label Selectors

```bash
# Get all dev applications
kubectl get applications -n argocd -l environment=dev

# Get specific service across all environments
kubectl get applications -n argocd -l service=productcatalog

# Get all applications for a specific instance
kubectl get applications -n argocd -l app.kubernetes.io/instance=astroshop-prod
```

## Best Practices

### Development Workflow

1. **Make Changes**: Update Helm values or charts in feature branch
2. **Test in Dev**: Changes auto-sync to dev environment
3. **Promote to QA**: Merge to main, QA auto-syncs
4. **Deploy to Prod**: Manual sync after approval

### Production Deployments

1. **Review Changes**: Check Git diff before syncing
2. **Use Dry Run**: Verify changes with `--dry-run` flag
3. **Sync During Windows**: Deploy during business hours only
4. **Monitor Health**: Watch application health post-deployment
5. **Keep Rollback Ready**: Know the previous revision number

### Security Considerations

- Production requires manual sync approval
- Sync windows restrict deployment times
- RBAC controls access to each environment
- Git repository access via tokens (not passwords)
- Separate AppProjects per environment

## Advanced Features

### Ignore Differences

The ApplicationSet ignores replica count differences (useful for HPA):

```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas
```

### Orphaned Resources

Orphaned resources are tracked but not automatically deleted:

```yaml
orphanedResources:
  warn: true  # Warn but don't delete
```

### Revision History

Limited to 3 revisions per application:

```yaml
revisionHistoryLimit: 3
```

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [GitOps Best Practices](https://www.gitops.tech/)
