output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.compute.alb_dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.storage.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation)"
  value       = module.storage.cloudfront_distribution_id
}

output "frontend_bucket_name" {
  description = "S3 bucket name for frontend assets"
  value       = module.storage.bucket_name
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = module.compute.redis_endpoint
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = var.ecr_repository_url
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.asg_name
}

output "cloudwatch_log_group_backend" {
  description = "CloudWatch log group for backend application"
  value       = module.monitoring.backend_log_group_name
}
