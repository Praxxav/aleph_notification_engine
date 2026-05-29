output "db_server_id" {
  value       = azurerm_postgresql_flexible_server.postgres.id
  description = "The ID of the PostgreSQL Flexible Server."
}

output "db_server_name" {
  value       = azurerm_postgresql_flexible_server.postgres.name
  description = "The name of the PostgreSQL Flexible Server."
}

output "db_server_fqdn" {
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
  description = "The fully qualified domain name (FQDN) of the PostgreSQL Flexible Server."
}

output "db_name" {
  value       = azurerm_postgresql_flexible_server_database.db.name
  description = "The name of the created database."
}
