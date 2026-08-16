variable "name_prefix" {
  description = "Prefix (already includes environment) used to name the VPC and subnet, e.g. 'qa-webapp'."
  type        = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_cidr" {
  description = "Primary IP range for the subnet."
  type        = string
}

variable "labels" {
  type    = map(string)
  default = {}
}
