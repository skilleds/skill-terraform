# tflint da casa (schematize-terraform). Copie para a raiz do repo.
# Rode: tflint --init && tflint --recursive --config "$PWD/.tflint.hcl"
# (--config absoluto: com --recursive o tflint procura o config relativo a cada diretório.)

config {
  call_module_type = "local" # inspeciona módulos locais; "all" baixa os remotos
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "all" # regras estritas: docs, tipos, nomes, versões pinadas
}

# Provider AWS (descomente se usar; fixe a versão e o SHA da release):
# plugin "aws" {
#   enabled = true
#   version = "0.49.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }

# Convenção da casa: snake_case no nome de recurso/variável/output.
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Toda variável e output tem description (módulo é interface pública).
rule "terraform_documented_variables" {
  enabled = true
}
rule "terraform_documented_outputs" {
  enabled = true
}

# Variável declarada e não usada, módulo sem versão pinada, required_providers ausente.
rule "terraform_unused_declarations" {
  enabled = true
}
rule "terraform_module_pinned_source" {
  enabled = true
  style   = "flexible"
}
rule "terraform_required_version" {
  enabled = true
}
rule "terraform_required_providers" {
  enabled = true
}
