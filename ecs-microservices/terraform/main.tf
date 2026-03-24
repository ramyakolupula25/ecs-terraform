terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after creating S3 bucket for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "ecs/terraform.tfstate"
  #   region = "ap-south-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── 1. VPC ────────────────────────────────────────
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
}

# ── 2. Security Groups ────────────────────────────
module "security_groups" {
  source       = "./modules/security-groups"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# ── 3. ECR Repositories ───────────────────────────
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

# ── 4. ALB + Target Groups ────────────────────────
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

# ── 5. ECS Cluster + IAM Roles + Task Definitions ─
module "ecs" {
  source                    = "./modules/ecs"
  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  ecs_sg_id                 = module.security_groups.ecs_sg_id
  frontend_ecr_url          = module.ecr.frontend_ecr_url
  backend_ecr_url           = module.ecr.backend_ecr_url
  frontend_target_group_arn = module.alb.frontend_target_group_arn
  backend_target_group_arn  = module.alb.backend_target_group_arn
  alb_dns_name              = module.alb.alb_dns_name
  capacity_provider_name    = module.asg.capacity_provider_name
}

# ── 6. ASG + Scaling Policies + Capacity Provider ─
module "asg" {
  source                    = "./modules/asg"
  project_name              = var.project_name
  environment               = var.environment
  ecs_cluster_name          = module.ecs.ecs_cluster_name
  ecs_sg_id                 = module.security_groups.ecs_sg_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  ecs_instance_profile_name = module.ecs.ecs_instance_profile_name

  instance_type    = var.instance_type
  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size
}

# ── Outputs ───────────────────────────────────────
output "app_url" {
  description = "Open this URL in your browser"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ecs_cluster_name" {
  value = module.ecs.ecs_cluster_name
}

output "asg_name" {
  value = module.asg.asg_name
}

output "sns_alerts_topic" {
  description = "Subscribe your email for scale-in/out alerts"
  value       = module.asg.sns_topic_arn
}

output "frontend_ecr_url" {
  value = module.ecr.frontend_ecr_url
}

output "backend_ecr_url" {
  value = module.ecr.backend_ecr_url
}
