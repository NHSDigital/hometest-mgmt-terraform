1. Add post-hook to delete s3 contents or change provider config if supports it.

---

## 🔒 Security Assessment Summary

### ✅ What's Already Good

| Component | Security Feature | Status |
|-----------|------------------|--------|
| **S3 Buckets** | Public access blocked, versioning, encryption | ✅ Implemented |
| **CloudFront** | OAC (not OAI), HTTPS-only, security headers, TLS 1.2+ | ✅ Implemented |
| **Lambda** | X-Ray tracing, CloudWatch logs, VPC support | ✅ Implemented |
| **RDS** | Secrets Manager for password, encryption at rest | ✅ Implemented |
| **SQS** | KMS encryption, DLQ configured | ✅ Implemented |
| **WAF** | Core rules, SQLi, IP reputation, rate limiting | ✅ Implemented |
| **KMS** | Key rotation enabled, service-specific policies | ✅ Implemented |
| **IAM** | Least privilege, account conditions | ✅ Implemented |

---

## 🚨 Security Improvements Recommended

### **CRITICAL - Must Fix**

| # | Issue | Current | Recommendation | Impact |
|---|-------|---------|----------------|--------|
| 1 | **API Gateway Resource Policy** | Missing | Add resource policy to restrict access | HIGH |
| 2 | **CloudTrail** | Not found | Enable for audit logging | HIGH |
| 3 | **GuardDuty** | Not found | Enable for threat detection | HIGH |
| 4 | **RDS deletion_protection** | `default = false` | Change to `true` for prod | HIGH |
| 5 | **RDS multi_az** | `default = false` | Enable for prod environments | MEDIUM |

### **HIGH - Should Fix**

| # | Issue | Current | Recommendation |
|---|-------|---------|----------------|
| 6 | **CloudFront access logging** | `default = false` | Enable by default |
| 7 | **RDS Performance Insights** | `default = false` | Enable for monitoring |
| 8 | **RDS Enhanced Monitoring** | `default = 0` | Set to 60 seconds minimum |
| 9 | **API Gateway WAF** | Optional | Make mandatory for internet-facing |
| 10 | **Lambda reserved concurrency** | Not set | Set limits to prevent resource exhaustion |

### **MEDIUM - Nice to Have**

| # | Issue | Recommendation |
|---|-------|----------------|
| 11 | **Security Hub** | Enable for centralized security findings |
| 12 | **AWS Config** | Enable for configuration compliance |
| 13 | **VPC Flow Logs** | Enable for network monitoring |
| 14 | **Macie** | Consider for S3 data classification |
| 15 | **Inspector** | Enable for Lambda vulnerability scanning |

---

## 📋 Detailed Recommendations

### 1. Add API Gateway Resource Policy
```hcl
# modules/api-gateway/main.tf - Add resource policy
resource "aws_api_gateway_rest_api_policy" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = "*"
      Action = "execute-api:Invoke"
      Resource = "${aws_api_gateway_rest_api.this.execution_arn}/*"
      Condition = {
        StringEquals = {
          "aws:SourceVpc" = var.allowed_vpc_id  # Or use CloudFront OAC
        }
      }
    }]
  })
}
```

### 2. Create CloudTrail Module
```hcl
# modules/cloudtrail/main.tf
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-audit-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  kms_key_id                   = var.kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }
}
```

### 3. Create GuardDuty Module
```hcl
# modules/guardduty/main.tf
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs { enable = true }
    kubernetes { audit_logs { enable = true } }
    malware_protection { scan_ec2_instance_with_findings { ebs_volumes { enable = true } } }
  }
}
```

### 4. Update RDS Default Values
```hcl
# src/rds-postgres/variables.tf - Change defaults for production safety
variable "deletion_protection" {
  default = true  # Changed from false
}

variable "multi_az" {
  default = true  # Changed from false for prod
}

variable "performance_insights_enabled" {
  default = true  # Changed from false
}

variable "monitoring_interval" {
  default = 60  # Changed from 0
}

variable "backup_retention_period" {
  default = 14  # Changed from 7
}
```

### 5. Add VPC Flow Logs to Network Module
```hcl
# src/network/vpc_flow_logs.tf
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = module.vpc.vpc_id
}
```

### 6. Enable Security Hub
```hcl
# modules/security-hub/main.tf
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}
```

### 7. Harden CloudFront CSP
```hcl
# Tighten Content Security Policy - remove unsafe-inline/unsafe-eval
variable "content_security_policy" {
  default = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://*.amazonaws.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self';"
}
```

### 8. Add Lambda Inspector Scanning
```hcl
resource "aws_inspector2_enabler" "lambda" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["LAMBDA", "LAMBDA_CODE"]
}
```

---

## 📊 AWS Security Hub Score Impact

| Improvement | Estimated Score Increase |
|-------------|-------------------------|
| Enable CloudTrail | +5-8% |
| Enable GuardDuty | +5-8% |
| Enable Security Hub | +3-5% |
| Enable VPC Flow Logs | +2-3% |
| RDS Multi-AZ + Deletion Protection | +2-3% |
| API Gateway Resource Policy | +2-3% |
| Enable Performance Insights | +1-2% |

**Estimated Total Improvement: +20-32%**

---

Would you like me to implement any of these security improvements? I can start with the most critical ones (CloudTrail, GuardDuty, Security Hub) or the quick wins (updating RDS defaults, enabling logging).


Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/environments/poc/dev2/terragrunt.hcl)

Searched for text `instance_class|memory_size|price_class|storage|allocated|timeout|reserved_concurrent` (`**/hometest-mgmt-terraform/**/*.tf`), 20 results

Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/modules/rds-postgres/variables.tf#40-40), lines 40 to 120

Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/modules/lambda/variables.tf#80-80), lines 80 to 130

Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/modules/cloudfront-spa/variables.tf#30-30), lines 30 to 60

Searched for text `memory_size|instance_class|allocated_storage` (`**/hometest-mgmt-terraform/**/*.hcl`), 20 results

Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/modules/deployment-artifacts/main.tf#80-80), lines 80 to 130

Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/environments/poc/core/rds-postgres/terragrunt.hcl#1-1), lines 1 to 60

Read [](file:///home/mikee/git/kainos/code/nhs/code/hometest-mgmt-terraform/infrastructure/environments/_envcommon/hometest-app.hcl#1-1), lines 1 to 60

Based on my analysis of the infrastructure, here's my **Cost Optimization Assessment**:

---

## 💰 Cost Optimization Summary

### ✅ Already Optimized

| Component | Current Setting | Status |
|-----------|-----------------|--------|
| **RDS Instance** | `db.t3.micro` (module default) / `db.t4g.micro` (POC) | ✅ Smallest instance |
| **CloudFront** | `PriceClass_100` (US, Canada, Europe only) | ✅ Cheapest tier |
| **S3 Lifecycle** | Transition to `STANDARD_IA` after 30 days | ✅ Good |
| **RDS Storage** | `gp3` (cheaper than gp2, no IOPS baseline) | ✅ Cost-effective |
| **Lambda Memory** | 256 MB default | ✅ Reasonable |
| **POC RDS Backup** | 3 days retention | ✅ Minimal |

---

## 🚀 Recommended Optimizations

### **HIGH IMPACT - Estimated Savings**

| # | Optimization | Current | Recommended | Est. Monthly Savings |
|---|--------------|---------|-------------|---------------------|
| 1 | **Lambda Memory Right-Sizing** | 256 MB all | 128 MB for simple APIs | ~$5-15/env |
| 2 | **RDS Stop Dev Instances** | Always running | Scheduled start/stop | ~$10-15/instance |
| 3 | **Lambda Graviton (ARM)** | x86_64 | arm64 runtime | ~20% Lambda costs |
| 4 | **S3 Intelligent Tiering** | Standard → IA | Intelligent Tiering | ~$1-5/bucket |
| 5 | **CloudWatch Logs Retention** | 14 days | 7 days for dev | ~$1-3/env |

### **MEDIUM IMPACT**

| # | Optimization | Description |
|---|--------------|-------------|
| 6 | **Lambda Provisioned Concurrency** | Avoid unless needed (expensive) |
| 7 | **NAT Gateway Elimination** | Use VPC endpoints for S3/DynamoDB |
| 8 | **Reserved Capacity** | Consider for prod RDS (1-3 year) |
| 9 | **Spot for CI/CD** | Use spot instances for builds |

---

## 📋 Specific Recommendations

### 1. Right-Size Lambda Memory (128 MB for Simple APIs)

For simple hello-world style lambdas, 128 MB is sufficient:

```hcl
# In terragrunt.hcl lambda definitions
lambdas = {
  "hello-world-lambda" = {
    memory_size = 128  # Reduced from 256
    timeout     = 10   # Reduced from 30
    ...
  }
}
```

### 2. Use ARM64 (Graviton) for Lambda - 20% cheaper

```hcl
# _envcommon/hometest-app.hcl
locals {
  lambda_runtime      = "nodejs20.x"
  lambda_architecture = ["arm64"]  # Add this - 20% cheaper
}
```

### 3. RDS Scheduled Start/Stop for Dev Environments

Create an EventBridge schedule to stop dev RDS during off-hours:

```hcl
# modules/rds-postgres/scheduled_stop.tf
resource "aws_scheduler_schedule" "stop_rds" {
  count = var.enable_scheduled_stop ? 1 : 0

  name       = "${var.identifier}-stop"
  schedule_expression = "cron(0 19 ? * MON-FRI *)"  # 7 PM weekdays

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:stopDBInstance"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ DbInstanceIdentifier = module.db.db_instance_identifier })
  }
}

resource "aws_scheduler_schedule" "start_rds" {
  count = var.enable_scheduled_stop ? 1 : 0

  name       = "${var.identifier}-start"
  schedule_expression = "cron(0 7 ? * MON-FRI *)"  # 7 AM weekdays

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:startDBInstance"
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ DbInstanceIdentifier = module.db.db_instance_identifier })
  }
}
```

**Savings: ~$10-15/month per dev instance** (14 hours × 30 days × ~$0.02/hr)

### 4. Reduce CloudWatch Log Retention for Dev

```hcl
# _envcommon/hometest-app.hcl - for dev environments
locals {
  log_retention_days = 7  # Reduced from 14 for dev
}
```

### 5. Add S3 Intelligent-Tiering for SPA Buckets

The deployment artifacts bucket already has transitions. Apply to SPA buckets:

```hcl
# modules/cloudfront-spa/main.tf - Add to existing lifecycle rules
rule {
  id     = "intelligent-tiering"
  status = "Enabled"

  transition {
    days          = 0
    storage_class = "INTELLIGENT_TIERING"
  }
}
```

### 6. Use VPC Endpoints Instead of NAT Gateway

If you have NAT Gateway (~$32/month + data charges), add VPC endpoints:

```hcl
# modules/vpc/endpoints.tf
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.private[*].id
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.private[*].id
}
```

---

## 📊 Estimated Monthly Savings Summary

| Environment | Current Est. | Optimized Est. | Savings |
|-------------|--------------|----------------|---------|
| **Dev1/Dev2/Dev3** (each) | ~$50-70 | ~$30-45 | ~$20-25/env |
| **RDS POC** | ~$15 | ~$8 (with stop/start) | ~$7 |
| **Total POC** | ~$200-250 | ~$120-160 | **~$80-90/month** |

---

## 🎯 Quick Wins to Implement Now

1. **Reduce Lambda memory to 128 MB** for simple APIs (hello-world, health checks)
2. **Add `arm64` architecture** to Lambda module for Graviton processors
3. **Reduce log retention** to 7 days for dev environments
4. **Implement RDS scheduled stop/start** for dev instances

Would you like me to implement any of these optimizations?
