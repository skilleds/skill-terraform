# State remoto, cifrado e com lock. UM state por ambiente/stack (blast radius).
# Os valores abaixo são de exemplo: troque pelo seu bucket. Credencial vem do ambiente
# (OIDC no CI), nunca deste arquivo. Variável não é permitida em backend no Terraform.
terraform {
  backend "s3" {
    bucket       = "acme-tfstate-hml"
    key          = "hml/core.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/tfstate-hml" # SSE-KMS: obrigatório no Terraform (sem criptografia de cliente); no OpenTofu soma-se ao encryption.tofu
    use_lockfile = true                # lock nativo do S3 (dynamodb_table está deprecado)
  }
}
