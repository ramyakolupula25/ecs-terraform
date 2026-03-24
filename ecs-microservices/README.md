# ECS Microservices — Full Infrastructure Project
### Terraform + GitHub Actions + EC2 + ASG + ALB + ECR

---

## Architecture

```
Internet
   │
   ▼
[ ALB ]  ──── /        ──►  ECS Service: Frontend (port 5000)
              /api/*   ──►  ECS Service: Backend  (port 5001)
                                    │
                              Private Subnets
                                    │
                         [ EC2 ECS Instances ]
                         managed by ASG (min 1, max 5)
                         scales on CPU / Memory / Schedule
```

---

## Project Structure

```
ecs-microservices/
├── app/
│   ├── frontend/              Flask frontend app + Dockerfile
│   └── backend/               Flask backend API + Dockerfile
├── .github/workflows/
│   └── ci-cd.yml              GitHub Actions pipeline
└── terraform/
    ├── main.tf                Wires all modules together
    ├── variables.tf
    ├── terraform.tfvars       Edit this to change sizing
    └── modules/
        ├── vpc/               VPC, subnets, IGW, NAT, route tables
        ├── security-groups/   ALB SG + ECS SG
        ├── ecr/               ECR repos + lifecycle policies
        ├── alb/               ALB + target groups + listener rules
        ├── ecs/               Cluster + IAM + task defs + services
        └── asg/               ← ASG module (see below)
```

---

## ASG Module — What's Inside

| Feature | Detail |
|---|---|
| Launch Template | Latest ECS-optimised AMI, auto-fetched via SSM |
| Auto Scaling Group | min=1, desired=2, max=5 |
| Scale-Out (CPU) | Add 1 instance when CPU > 70% |
| Scale-In  (CPU) | Remove 1 instance when CPU < 20% |
| Scale-Out (Memory) | Add 1 instance when Memory > 75% |
| Target Tracking | Keeps ASG CPU at 60% average |
| Scheduled Scaling | Scale up 8 AM IST, scale down 8 PM IST (Mon–Fri) |
| ECS Capacity Provider | Links ASG to ECS cluster automatically |
| SNS Notifications | Alerts on every scale event |
| Instance Refresh | Rolling replacement — zero downtime on AMI update |

---

## Step-by-Step Setup

### Step 1 — Prerequisites

```bash
# Install these tools first
terraform --version    # >= 1.5.0
aws --version          # AWS CLI v2
docker --version
git --version
```

### Step 2 — Configure AWS CLI

```bash
aws configure
# Enter: Access Key ID, Secret Key, Region: ap-south-1, Format: json
```

### Step 3 — Provision Infrastructure

```bash
cd terraform/

terraform init
terraform plan
terraform apply -auto-approve
```

> Takes ~10 minutes. At the end you will see:
> `app_url = "http://your-alb-dns-name.ap-south-1.elb.amazonaws.com"`

### Step 4 — Add GitHub Secrets

Go to GitHub repo → **Settings → Secrets → Actions** → add:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret key |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |

### Step 5 — Push & Deploy

```bash
git init
git add .
git commit -m "Initial ECS microservices project"
git remote add origin https://github.com/YOUR_USERNAME/ecs-microservices.git
git branch -M main
git push -u origin main
```

GitHub Actions will automatically build, push, and deploy! ✅

---

## Useful Commands

```bash
# View running ECS tasks
aws ecs list-tasks --cluster ecs-microservices-cluster

# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ecs-microservices-asg

# View CloudWatch logs (frontend)
aws logs tail /ecs/ecs-microservices/frontend --follow

# Manually trigger scale out
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ecs-microservices-asg \
  --desired-capacity 3
```

---

## Resume Bullet Points

- Provisioned AWS ECS (EC2 launch type) cluster using Terraform with modular IaC structure
- Implemented Auto Scaling Group (ASG) with CPU, memory, and scheduled scaling policies
- Built GitHub Actions CI/CD pipeline to automate Docker build, ECR push, and ECS deployment
- Configured ALB with path-based routing to distribute traffic between frontend and backend services
- Set up CloudWatch alarms and SNS notifications for scale-in/scale-out events

---

## Cleanup

```bash
cd terraform/
terraform destroy -auto-approve
```
