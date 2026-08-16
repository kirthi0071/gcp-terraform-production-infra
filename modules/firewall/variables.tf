variable "name_prefix" { type = string }
variable "project_id" { type = string }
variable "network_id" {
  description = "VPC self-link/ID from the network module."
  type        = string
}

variable "app_target_tags" {
  description = "Network tags applied to the VM(s) these rules protect."
  type        = list(string)
  default     = ["app"]
}

variable "app_port" {
  description = "TCP port the application listens on (targeted by the LB health check + backend traffic)."
  type        = number
  default     = 8080
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed to SSH in. Required, no default -- caller must be explicit."
  type        = list(string)
}

variable "enable_ssh_from_anywhere" {
  description = "Explicit opt-in to allow 0.0.0.0/0 for SSH. Defaults to false."
  type        = bool
  default     = false
}

variable "labels" {
  type    = map(string)
  default = {}
}
