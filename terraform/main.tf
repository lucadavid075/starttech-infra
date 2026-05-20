terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "starttech-infra-state-114324232512"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "StartTech"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "networking" {
  source = "./modules/networking"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "storage" {
  source = "./modules/storage"

  environment          = var.environment
  frontend_bucket_name = var.frontend_bucket_name
  domain_name          = var.domain_name
}

module "compute" {
  source = "./modules/compute"

  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  instance_type      = var.instance_type
  min_size           = var.asg_min_size
  max_size           = var.asg_max_size
  desired_capacity   = var.asg_desired_capacity
  ecr_repository_url = var.ecr_repository_url
  mongo_uri          = var.mongo_uri
  jwt_secret         = var.jwt_secret
  allowed_origins    = var.allowed_origins
  key_name           = var.key_name
  redis_node_type    = var.redis_node_type
}

module "monitoring" {
  source = "./modules/monitoring"

  environment    = var.environment
  asg_name       = module.compute.asg_name
  alb_arn_suffix = module.compute.alb_arn_suffix
  alarm_email    = var.alarm_email
}
