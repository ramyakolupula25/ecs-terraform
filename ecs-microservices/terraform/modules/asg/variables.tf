variable "project_name"              { type = string }
variable "environment"               { type = string }
variable "ecs_cluster_name"          { type = string }
variable "ecs_sg_id"                 { type = string }
variable "private_subnet_ids"        { type = list(string) }
variable "ecs_instance_profile_name" { type = string }

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 5
}
