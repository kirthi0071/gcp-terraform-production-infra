variable "project_id" { type = string }
variable "name_prefix" { type = string }
variable "region" { type = string }
variable "network_id" {
  description = "VPC self-link for private services access peering."
  type        = string
}
variable "db_version" { type = string }
variable "tier" { type = string }
variable "disk_size_gb" { type = number }
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "app_db_name" {
  type    = string
  default = "appdb"
}
variable "app_db_user" {
  type    = string
  default = "appuser"
}
variable "labels" {
  type    = map(string)
  default = {}
}
