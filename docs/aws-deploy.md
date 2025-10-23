## Krayin on AWS (EC2 + Docker Compose)

This guide prepares the app for AWS. It assumes:
- EC2 for compute (Amazon Linux 2023)
- RDS MySQL 8 for database
- ElastiCache Redis for cache/sessions
- SES for email
- Optional: S3 for storage, SQS for queues

### 1) Build images locally (optional) or on EC2

On EC2:
```bash
sudo yum install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker

git clone https://your-repo.git krayin
cd krayin/deploy/aws
# Create env from sample
cp ../../docs/env.aws.example .env
# Edit .env with your RDS/Redis/SES/S3 settings

docker compose build
docker compose up -d
```

App will be on port 80. Use an ALB or attach an Elastic IP.

### 2) AWS resources
- RDS MySQL: create DB, note endpoint, user, password. Restrict SG to EC2.
- ElastiCache Redis: create cluster, note primary endpoint. SG to EC2.
- SES: verify domain/sender, move out of sandbox, use `MAIL_MAILER=ses`.
- S3 (optional): create bucket; set `FILESYSTEM_DISK=s3` and related AWS vars.

### 3) Environment
Update `deploy/aws/.env`:
- `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL=https://your-domain.com`
- DB vars point to RDS
- `CACHE_DRIVER=redis`, `SESSION_DRIVER=redis`, Redis host points to ElastiCache
- `RUN_MIGRATIONS=true` on first deploy (can keep true)

### 4) TLS
Terminate TLS at ALB or add an Nginx cert. For ALB, forward 443→80.

### 5) Zero-downtime updates
```bash
cd deploy/aws
git pull
docker compose build
docker compose up -d
```

### 6) Logs and backups
- Route Nginx access/error logs to CloudWatch via the EC2 agent if needed.
- Schedule automated RDS snapshots and S3 lifecycle policies.

### 7) ECS (optional)
For ECS Fargate, push two images (app, nginx) to ECR and create a task with both containers on the same task network. Point Nginx `fastcgi_pass` to `app:9000`. Use task env vars/secrets. Migrate via one-off task.


