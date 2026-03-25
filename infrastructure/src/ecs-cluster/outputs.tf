################################################################################
# ECS Cluster Outputs
################################################################################

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

output "service_discovery_namespace_id" {
  description = "ID of the Cloud Map service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_arn" {
  description = "ARN of the Cloud Map service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_discovery_namespace_name" {
  description = "Name of the Cloud Map service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}
