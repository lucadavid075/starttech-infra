# ─── Security Groups ──────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "starttech-${var.environment}-alb-sg"
  description = "Allow HTTP/HTTPS inbound to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "starttech-${var.environment}-alb-sg" }
}

resource "aws_security_group" "backend" {
  name        = "starttech-${var.environment}-backend-sg"
  description = "Allow traffic from ALB to backend EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow ALB to reach backend"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH from within VPC only"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "starttech-${var.environment}-backend-sg" }
}

resource "aws_security_group" "redis" {
  name        = "starttech-${var.environment}-redis-sg"
  description = "Allow Redis traffic from backend EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "Redis from backend only"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "starttech-${var.environment}-redis-sg" }
}

# ─── IAM Role for EC2 ─────────────────────────────────────────────────────────
resource "aws_iam_role" "backend_ec2" {
  name = "starttech-${var.environment}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.backend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.backend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.backend_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "backend_ec2" {
  name = "starttech-${var.environment}-backend-profile"
  role = aws_iam_role.backend_ec2.name
}

# ─── ElastiCache Redis ────────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "redis" {
  name       = "starttech-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "starttech-${var.environment}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = { Name = "starttech-${var.environment}-redis" }
}

# ─── Application Load Balancer ────────────────────────────────────────────────
resource "aws_lb" "backend" {
  name               = "starttech-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = { Name = "starttech-${var.environment}-alb" }
}

resource "aws_lb_target_group" "backend" {
  name     = "starttech-${var.environment}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = { Name = "starttech-${var.environment}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ─── Launch Template ──────────────────────────────────────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "backend" {
  name_prefix   = "starttech-${var.environment}-backend-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile { arn = aws_iam_instance_profile.backend_ec2.arn }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.backend.id]
  }

  monitoring { enabled = true }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    ecr_repository_url = var.ecr_repository_url
    aws_region         = "us-east-1"
    mongo_uri          = var.mongo_uri
    jwt_secret         = var.jwt_secret
    allowed_origins    = var.allowed_origins
    redis_addr         = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379"
    environment        = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "starttech-${var.environment}-backend" }
  }

  lifecycle { create_before_destroy = true }
}

# ─── Auto Scaling Group ───────────────────────────────────────────────────────
resource "aws_autoscaling_group" "backend" {
  name                      = "starttech-${var.environment}-asg"
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.backend.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "starttech-${var.environment}-backend"
    propagate_at_launch = true
  }

  lifecycle { create_before_destroy = true }
}

# ─── ASG Scaling Policies ─────────────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "starttech-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "starttech-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "starttech-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale up when CPU > 70% for 2 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = { AutoScalingGroupName = aws_autoscaling_group.backend.name }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "starttech-${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Scale down when CPU < 20% for 5 minutes"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = { AutoScalingGroupName = aws_autoscaling_group.backend.name }
}
