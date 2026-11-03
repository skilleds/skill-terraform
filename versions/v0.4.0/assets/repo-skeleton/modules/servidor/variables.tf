variable "nome" {
  description = "Nome do servidor (minúsculas, dígitos e hífen)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.nome))
    error_message = "nome deve casar ^[a-z][a-z0-9-]{1,40}$ (minúsculas, dígitos, hífen)."
  }
}

variable "ambiente" {
  description = "Ambiente dono do recurso."
  type        = string

  validation {
    condition     = contains(["hml", "prd"], var.ambiente)
    error_message = "ambiente deve ser hml ou prd."
  }
}

variable "tipo" {
  description = "Tipo do servidor Hetzner (ex.: cx22)."
  type        = string
  default     = "cx22"
}

variable "localizacao" {
  description = "Localização Hetzner (ex.: nbg1, fsn1, hel1)."
  type        = string
  default     = "nbg1"
}

variable "ssh_key_ids" {
  description = "IDs das chaves SSH públicas já cadastradas."
  type        = list(number)

  validation {
    condition     = length(var.ssh_key_ids) > 0
    error_message = "informe ao menos uma chave SSH (sem senha de root por e-mail)."
  }
}

variable "ssh_permitido_de" {
  description = "CIDRs com acesso SSH. Nunca 0.0.0.0/0 em prd."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.ssh_permitido_de : can(cidrhost(c, 0))])
    error_message = "todo item de ssh_permitido_de deve ser um CIDR válido."
  }

  validation {
    condition     = var.ambiente != "prd" || !contains(var.ssh_permitido_de, "0.0.0.0/0")
    error_message = "SSH aberto ao mundo (0.0.0.0/0) é vetado em prd."
  }
}

variable "protegido" {
  description = "Liga delete_protection e rebuild_protection (true em prd)."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels obrigatórias: owner, project, managed_by."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["owner", "project", "managed_by"] : contains(keys(var.labels), k)])
    error_message = "labels deve conter owner, project e managed_by."
  }
}
