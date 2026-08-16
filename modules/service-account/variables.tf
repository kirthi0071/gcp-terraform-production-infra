variable "name_prefix" { type = string }
variable "project_id" { type = string }

variable "extra_roles" {
  description = "Additional project-level IAM roles beyond the minimal default set. Use sparingly."
  type        = list(string)
  default     = []
}
