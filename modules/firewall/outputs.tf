output "ssh_rule_id" {
  value = google_compute_firewall.allow_ssh.id
}

output "lb_health_check_rule_id" {
  value = google_compute_firewall.allow_lb_health_check.id
}
