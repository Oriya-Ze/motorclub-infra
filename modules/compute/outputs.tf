output "ecr_backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.api.name
}

output "migration_task_definition_arn" {
  value = aws_ecs_task_definition.api.arn
}

output "migration_task_definition_family" {
  value = aws_ecs_task_definition.api.family
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "ecs_security_group_id" {
  value = var.ecs_security_group_id
}

output "private_app_subnet_ids" {
  value = var.private_app_subnet_ids
}
