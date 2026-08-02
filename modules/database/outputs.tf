output "db_instance_address" {
  value = aws_db_instance.main.address
}

output "db_instance_port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = var.db_name
}

output "database_secret_arn" {
  value = aws_secretsmanager_secret.database.arn
}

output "application_secret_arn" {
  value = aws_secretsmanager_secret.application.arn
}

output "database_secret_name" {
  value = aws_secretsmanager_secret.database.name
}
