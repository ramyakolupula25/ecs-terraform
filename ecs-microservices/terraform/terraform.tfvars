# ── Project Config ────────────────────────────────
aws_region   = "ap-south-1"   # Mumbai (closest to Hyderabad)
project_name = "ecs-microservices"
environment  = "dev"

# ── ASG / EC2 Sizing ──────────────────────────────
instance_type    = "t3.small"   # Change to t3.medium for more power
desired_capacity = 2             # Start with 2 instances
min_size         = 1             # Never go below 1
max_size         = 5             # Never go above 5
