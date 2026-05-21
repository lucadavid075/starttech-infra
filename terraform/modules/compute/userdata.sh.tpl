#!/bin/bash
set -euo pipefail

# ── System setup ──────────────────────────────────────────────────────────────
yum update -y
yum install -y docker aws-cli amazon-cloudwatch-agent jq

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# ── CloudWatch Agent config ───────────────────────────────────────────────────
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CW_CONFIG'
{
  "agent": { "metrics_collection_interval": 60, "logfile": "/var/log/amazon-cloudwatch-agent.log" },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/starttech-backend.log",
            "log_group_name": "/starttech/${environment}/backend",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "StartTech/${environment}",
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_idle", "cpu_usage_user"], "metrics_collection_interval": 60 },
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"], "metrics_collection_interval": 60 }
    }
  }
}
CW_CONFIG

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# ── ECR login & pull ──────────────────────────────────────────────────────────
aws ecr get-login-password --region ${aws_region} \
  | docker login --username AWS --password-stdin ${ecr_repository_url}

docker pull ${ecr_repository_url}:latest

# ── Run backend container ─────────────────────────────────────────────────────
docker run -d \
  --name starttech-backend \
  --restart unless-stopped \
  -p 8080:8080 \
  -e PORT=8080 \
  -e MONGO_URI="${mongo_uri}" \
  -e DB_NAME=much_todo_db \
  -e JWT_SECRET_KEY="${jwt_secret}" \
  -e JWT_EXPIRATION_HOURS=72 \
  -e ENABLE_CACHE=true \
  -e REDIS_ADDR="${redis_addr}" \
  -e ALLOWED_ORIGINS="${allowed_origins}" \
  -e SECURE_COOKIE=false \
  -e LOG_LEVEL=INFO \
  -e LOG_FORMAT=json \
  --log-driver=awslogs \
  --log-opt awslogs-region=${aws_region} \
  --log-opt awslogs-group=/starttech/${environment}/backend \
  --log-opt awslogs-stream=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  ${ecr_repository_url}:latest

# ── Health check loop ─────────────────────────────────────────────────────────
for i in $(seq 1 30); do
  if curl -sf http://localhost:8080/health; then
    echo "Backend healthy after $i attempts"
    break
  fi
  sleep 5
done
