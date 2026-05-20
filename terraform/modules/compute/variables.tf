variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "min_size" {
 type = number
 default = 1 
}
variable "max_size" {
 type = number
 default = 4
}
variable "desired_capacity" {
 type = number
 default = 2
}
variable "ecr_repository_url" { type = string }
variable "mongo_uri" {
 type = string
 sensitive = true
}
variable "jwt_secret" {
 type = string
 sensitive = true
}
variable "allowed_origins" { type = string }
variable "key_name" {
 type = string
 default = ""
}
variable "redis_node_type" { 
  type = string
  default = "cache.t3.micro" 
 }
