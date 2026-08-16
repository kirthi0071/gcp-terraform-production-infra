variable "project_id" { type = string }
variable "name_prefix" { type = string }
variable "backend_instance_group" {
  description = "Self-link of the MIG (from the vm module) to attach as the backend."
  type        = string
}
variable "app_port" {
  type    = number
  default = 8080
}
variable "labels" {
  type    = map(string)
  default = {}
}
