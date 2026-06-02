resource "random_password" "db_pass" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "db-aleph-${var.environment}-${substr(md5(var.resource_group_name), 0, 6)}"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  delegated_subnet_id    = var.subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  administrator_login    = var.admin_username
  administrator_password = random_password.db_pass.result
  public_network_access_enabled = false
  
  # Highly cost-effective tier for dev/test and lightweight prod workloads
  sku_name               = "B_Standard_B1ms"
  storage_mb             = 32768

  # Disable high availability to optimize cost (can be enabled in production variables if required)
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  lifecycle {
    ignore_changes = [
      zone,
    ]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Save DB Administrator Password to Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_pass.result
  key_vault_id = var.key_vault_id
}

# Construct and Save Full DATABASE_URL to Key Vault for application use
resource "azurerm_key_vault_secret" "database_url" {
  name         = "DATABASE-URL"
  value        = "postgresql://${var.admin_username}:${urlencode(random_password.db_pass.result)}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${var.db_name}?sslmode=require"
  key_vault_id = var.key_vault_id
}
