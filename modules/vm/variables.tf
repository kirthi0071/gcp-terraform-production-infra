variable "project_id" { type = string }
variable "name_prefix" { type = string }
variable "region" { type = string }
variable "zone" { type = string }
variable "machine_type" { type = string }
variable "image" { type = string }
variable "subnet_self_link" { type = string }
variable "service_account_email" { type = string }

variable "network_tags" {
  type    = list(string)
  default = ["app"]
}

variable "boot_disk_size_gb" {
  type    = number
  default = 20
}

variable "boot_disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "target_size" {
  description = "Number of VM instances the Managed Instance Group should run."
  type        = number
  default     = 2
}

variable "ssh_public_key" {
  description = "Optional SSH PUBLIC key material ('username:ssh-rsa AAAA...'). Never pass a private key -- Terraform must never manage private key material. Leave null to skip metadata-based SSH keys entirely (e.g. if using OS Login instead)."
  type        = string
  default     = null
}

variable "labels" {
  type    = map(string)
  default = {}
}
