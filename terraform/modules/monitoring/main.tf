# ─── CloudWatch Log Groups ────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/starttech/${var.environment}/backend"
  retention_in_days = 30
  tags              = { Name = "starttech-${var.environment}-backend-logs" }
}

resource "aws_cloudwatch_log_group" "infrastructure" {
  name              = "/starttech/${var.environment}/infrastructure"
  retention_in_days = 14
  tags              = { Name = "starttech-${var.environment}-infra-logs" }
}

# ─── SNS Topic for Alarms ────────────────────────────────────────────────────
resource "aws_sns_topic" "alarms" {
  name = "starttech-${var.environment}-alarms"
  tags = { Name = "starttech-${var.environment}-alarms" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ─── ALB Alarms ───────────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "starttech-${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors exceeded threshold"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = { LoadBalancer = var.alb_arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "starttech-${var.environment}-alb-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 2
  alarm_description   = "P95 response time exceeded 2 seconds"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = { LoadBalancer = var.alb_arn_suffix }
}

# ─── CloudWatch Dashboard ─────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "StartTech-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "ALB Request Count"
          period = 60
		  region = "us-east-1"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]]
          view   = "timeSeries"
          stat   = "Sum"
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ALB 5XX Errors"
          period = 60
		  region = "us-east-1"
          metrics = [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]]
          view   = "timeSeries"
          stat   = "Sum"
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ASG Instance Count"
          period = 60
		  region = "us-east-1"
          metrics = [["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.asg_name]]
          view   = "timeSeries"
          stat   = "Average"
        }
      },
      {
        type = "log"
        properties = {
          title   = "Backend Error Logs"
          query   = "SOURCE '/starttech/${var.environment}/backend' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50"
          region  = "us-east-1"
          view    = "table"
        }
      }
    ]
  })
}
