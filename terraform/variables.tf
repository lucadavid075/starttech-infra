variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (prod, staging)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "frontend_bucket_name" {
  description = "S3 bucket name for the React frontend"
  type        = string
  default     = "starttech-frontend-prod"
}

variable "domain_name" {
  description = "Domain name for CloudFront (optional, leave empty for default CF domain)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for the backend"
  type        = string
  default     = "t3.small"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances in the ASG"
  type        = number
  default     = 2
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the backend Docker image"
  type        = string
}

variable "mongo_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret key for the backend"
  type        = string
  sensitive   = true
}

variable "allowed_origins" {
  description = "Comma-separated allowed CORS origins"
  type        = string
  default     = "https://your-cloudfront-domain.cloudfront.net"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms"
  type        = string
  default     = "ops@starttech.com"
}
