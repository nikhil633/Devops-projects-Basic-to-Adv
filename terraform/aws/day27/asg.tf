resource "aws_launch_template" "name" {
  name_prefix = "app-launch-template"
  image_id = var.image_id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [
    aws_security_group.app_sg.id,
    aws_security_group.allow_ssh.id
  ]

  user_data = filebase64("${path.module}/scripts/user_data.sh")
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name = "app-asg-${var.environment}"
  min_size = var.min_size
  max_size = var.max_size
  desired_capacity = var.desired_capacity
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns = [aws_lb_target_group.app_tg.arn]
  health_check_type = "ELB"
  health_check_grace_period = 300

  launch_template {
    id = aws_launch_template.name.id
    version = "$latest"
  }

  tag {
    Key = "Name"
    value = "app-instance-${var.environment}"
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_policy" "scale_out" {
  name = "scale-out-${var.environment}"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "scale_In" {
  name = "scale-In-${var.environment}"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

