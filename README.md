# starttech-infra

Infrastructure as Code (Terraform) for the **MuchToDo** full-stack platform — StartTech Company.

## Architecture

![Architecture Diagram](./architecture.png)

```
Users
  │
  ├── Amazon CloudFront (CDN + HTTPS)
  │       └── Amazon S3 (React frontend — static assets)
  │
  └── Application Load Balancer (HTTP/80)
          │
          ├── Private Subnet AZ-A → EC2 ASG (Dockerized Go API)
          └── Private Subnet AZ-B → EC2 ASG (Dockerized Go API)
                    │
                    ├── MongoDB Atlas      (user & task data)
                    ├── Amazon ElastiCache (Redis — username cache)
                    └── Amazon CloudWatch  (structured JSON logs)
```

### Infrastructure Components

| Layer | Component | Details |
|---|---|---|
| **Network** | VPC | `10.0.0.0/16` across 2 AZs |
| | Public Subnets | ALB + NAT Gateways |
| | Private Subnets | EC2 instances + ElastiCache |
| | NAT Gateways | One per AZ for HA egress |
| **Frontend** | S3 | Static React assets |
| | CloudFront | CDN with OAC, HTTPS redirect, SPA fallback |
| **Backend** | ALB | HTTP/80 → EC2:8080, `/health` check |
| | EC2 ASG | 1–4 × t3.small, Amazon Linux 2023 |
| | Launch Template | Docker pull from ECR + CloudWatch agent bootstrap |
| | ECR | Docker image registry (scan-on-push, 10-image lifecycle) |
| **Cache** | ElastiCache Redis 7.1 | `cache.t3.micro`, private subnet |
| **Database** | MongoDB Atlas | External SaaS — `much_todo_db` |
| **IAM** | EC2 Instance Role | ECR pull + CloudWatch agent + SSM access |
| **Monitoring** | CloudWatch Logs | `/starttech/prod/backend` — 30-day retention |
| | CloudWatch Alarms | ALB 5xx, ALB latency p95, CPU scale-up/down |
| | CloudWatch Dashboard | Requests, errors, CPU, instance count, error logs |
| | SNS | Email alerts for all alarms |

---

## CI/CD Pipeline

```
Push to main
    │
    ├── Validate & Scan (tfsec)
    │
    ├── Terraform Plan (posted as PR comment)
    │
    └── Terraform Apply (on merge to main)
            └── Updates Launch Template → triggers ASG instance refresh
```

**Trigger on:** push to `main` (apply) · PR to `main` (plan only) · manual `workflow_dispatch` (plan / apply / destroy)

---

## Repository Structure

```
starttech-infra/
├── .github/workflows/
│   └── infrastructure-deploy.yml   # validate → plan → apply pipeline
├── bootstrap/
│   └── main.tf                     # one-time S3 state bucket creation
├── terraform/
│   ├── main.tf                     # root module — wires all modules
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── networking/             # VPC, subnets, NAT gateways, route tables
│       ├── storage/                # S3, CloudFront OAC, ECR
│       ├── compute/                # ALB, ASG, Launch Template, ElastiCache, IAM
│       └── monitoring/             # CloudWatch log groups, alarms, dashboard, SNS
├── monitoring/
│   ├── cloudwatch-dashboard.json   # dashboard widget definitions
│   ├── alarm-definitions.json      # alarm catalogue
│   └── log-insights-queries.txt    # 7 ready-to-use Log Insights queries
└── scripts/
    └── deploy-infrastructure.sh    # local deploy helper (plan | apply | destroy)
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Terraform | ≥ 1.10 |
| AWS CLI | ≥ 2.x |
| Git | any |

IAM user must have `StartTechCICD-1` and `StartTechCICD-2` policies attached.

---

## First-time Setup

### 1. Bootstrap the S3 state bucket (once only)

```bash
cd bootstrap
terraform init
terraform apply
```

This creates `starttech-infra-state-<account_id>` with versioning and encryption. Update `terraform/main.tf` backend block with the bucket name.

### 2. Set GitHub Secrets (starttech-infra repo)

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `MONGO_URI` | `mongodb+srv://user:pass@cluster.mongodb.net/` |
| `JWT_SECRET` | Strong random string |
| `ALARM_EMAIL` | Email for CloudWatch alerts |
| `ALLOWED_ORIGINS` | `https://<your-cloudfront-domain>.cloudfront.net` |
| `FRONTEND_BUCKET_NAME` | `starttech-frontend-prod-<account_id>` |
| `ECR_REPOSITORY_URL` | `<account_id>.dkr.ecr.us-east-1.amazonaws.com/starttech-backend` |

### 3. Create a PR → merge to main

```bash
git checkout -b feature/initial-infrastructure
git add .
git commit -m "feat(infra): initial infrastructure setup"
git push -u origin feature/initial-infrastructure
```

Open PR → pipeline runs validate + plan → merge → pipeline applies (~10–12 min).

### 4. Capture outputs for starttech-application

After apply, go to **Actions → latest run → Summary**:

| Output | Use as secret in starttech-application |
|---|---|
| `alb_dns_name` | `ALB_DNS_NAME` and `VITE_API_BASE_URL` (prefix `http://`) |
| `asg_name` | `ASG_NAME` |
| `cloudfront_domain_name` | `CLOUDFRONT_DOMAIN` |
| `cloudfront_distribution_id` | `CLOUDFRONT_DISTRIBUTION_ID` |
| `frontend_bucket_name` | `FRONTEND_BUCKET_NAME` |

Add both NAT Gateway EIPs to **MongoDB Atlas → Network Access**.

---

## Destroying Infrastructure

**Via pipeline (recommended):**
GitHub → Actions → Infrastructure Deploy → Run workflow → select `destroy`

**Via CLI:**
```bash
cd terraform && terraform destroy
```

> The S3 state bucket is **not** destroyed — it is managed by `bootstrap/` and must be deleted manually if no longer needed.

---

## Monitoring

| Alarm | Condition | Action |
|---|---|---|
| `starttech-prod-alb-5xx` | > 10 errors/min for 2 periods | SNS email |
| `starttech-prod-alb-latency` | p95 > 2s for 3 periods | SNS email |
| `starttech-prod-cpu-high` | CPU > 70% for 2 periods | Scale up +1 |
| `starttech-prod-cpu-low` | CPU < 20% for 5 periods | Scale down -1 |

CloudWatch dashboard: **AWS Console → CloudWatch → Dashboards → StartTech-prod**

Log Insights queries: `monitoring/log-insights-queries.txt`
