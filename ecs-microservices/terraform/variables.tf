variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used to prefix all resources"
  type        = string
  default     = "ecs-microservices"
}

variable "environment" {
  description = "Environment: dev / staging / prod"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type for ECS nodes"
  type        = string
  default     = "t3.small"
}

variable "desired_capacity" {
  description = "Initial number of ECS EC2 instances"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of ECS EC2 instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of ECS EC2 instances"
  type        = number
  default     = 5
}
