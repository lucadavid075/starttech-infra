output "alb_dns_name" { value = aws_lb.backend.dns_name }
output "alb_arn_suffix" { value = aws_lb.backend.arn_suffix }
output "asg_name" { value = aws_autoscaling_group.backend.name }
output "redis_endpoint" { value = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379" }
output "backend_sg_id" { value = aws_security_group.backend.id }
