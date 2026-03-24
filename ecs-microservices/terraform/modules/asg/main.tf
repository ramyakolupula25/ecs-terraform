# ── Launch Template for ECS EC2 Instances ─────────
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-lt-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.ecs_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ecs_sg_id]
    delete_on_termination       = true
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.ecs_cluster_name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true  >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true       >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-ecs-instance"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Auto Scaling Group ─────────────────────────────
resource "aws_autoscaling_group" "ecs" {
  name                      = "${var.project_name}-ecs-asg"
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300
  protect_from_scale_in     = true   # ECS manages scale-in

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# ── ECS Capacity Provider (links ASG ↔ ECS) ───────
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 80     # keep ASG at 80% utilization
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 3
    }
  }
}

# ── Scale-Out Policy: CPU High ─────────────────────
resource "aws_autoscaling_policy" "scale_out_cpu" {
  name                   = "${var.project_name}-scale-out-cpu"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when CPU > 70%"
  alarm_actions       = [aws_autoscaling_policy.scale_out_cpu.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs.name
  }
}

# ── Scale-In Policy: CPU Low ───────────────────────
resource "aws_autoscaling_policy" "scale_in_cpu" {
  name                   = "${var.project_name}-scale-in-cpu"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale in when CPU < 20%"
  alarm_actions       = [aws_autoscaling_policy.scale_in_cpu.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs.name
  }
}

# ── Scale-Out Policy: Memory High ─────────────────
resource "aws_autoscaling_policy" "scale_out_memory" {
  name                   = "${var.project_name}-scale-out-memory"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project_name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Scale out when Memory > 75%"
  alarm_actions       = [aws_autoscaling_policy.scale_out_memory.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs.name
  }
}

# ── Target Tracking: ALB Request Count ────────────
resource "aws_autoscaling_policy" "target_tracking_alb" {
  name                   = "${var.project_name}-target-tracking-alb"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value       = 60.0
    disable_scale_in   = false
  }
}

# ── Scheduled Scaling: Business Hours ─────────────
# Scale up at 8am IST (2:30 UTC), scale down at 8pm IST (14:30 UTC)
resource "aws_autoscaling_schedule" "scale_up_morning" {
  scheduled_action_name  = "${var.project_name}-scale-up-morning"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  recurrence             = "30 2 * * MON-FRI"   # 8:00 AM IST
  desired_capacity       = var.max_size
  min_size               = var.min_size
  max_size               = var.max_size
}

resource "aws_autoscaling_schedule" "scale_down_evening" {
  scheduled_action_name  = "${var.project_name}-scale-down-evening"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  recurrence             = "30 14 * * MON-FRI"  # 8:00 PM IST
  desired_capacity       = var.min_size
  min_size               = var.min_size
  max_size               = var.max_size
}

# ── SNS Notification on Scaling Events ────────────
resource "aws_sns_topic" "asg_notifications" {
  name = "${var.project_name}-asg-notifications"
}

resource "aws_autoscaling_notification" "asg_notify" {
  group_names = [aws_autoscaling_group.ecs.name]
  topic_arn   = aws_sns_topic.asg_notifications.arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}

# ── Outputs ───────────────────────────────────────
output "asg_name" {
  value = aws_autoscaling_group.ecs.name
}

output "asg_arn" {
  value = aws_autoscaling_group.ecs.arn
}

output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.main.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.asg_notifications.arn
}
