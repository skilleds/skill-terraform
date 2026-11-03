output "id" {
  description = "ID do servidor."
  value       = hcloud_server.this.id
}

output "ipv4" {
  description = "IPv4 público."
  value       = hcloud_server.this.ipv4_address
}
