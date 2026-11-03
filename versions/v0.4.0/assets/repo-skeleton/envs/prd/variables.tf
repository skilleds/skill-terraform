variable "ssh_key_ids" {
  description = "IDs das chaves SSH públicas cadastradas no projeto Hetzner."
  type        = list(number)
}

variable "ssh_permitido_de" {
  description = "CIDRs com acesso SSH."
  type        = list(string)
}
