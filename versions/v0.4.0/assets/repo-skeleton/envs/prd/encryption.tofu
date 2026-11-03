# Criptografia do state e do plan NO CLIENTE (OpenTofu >= 1.7). Arquivo *.tofu: o Terraform o IGNORA.
# Se este repo usa Terraform, apague este arquivo e troque o lock pelo de repo-skeleton-terraform/
# (e use backend com encrypt + kms_key_id: ver assets/backend/s3.tf.example).
# Chave em KMS: nenhum segredo no código. Sem KMS: exporte TF_ENCRYPTION (pbkdf2) a partir do cofre do CI.
terraform {
  encryption {
    key_provider "aws_kms" "estado" {
      kms_key_id = "alias/tofu-state-prd"
      region     = "us-east-1"
      key_spec   = "AES_256"
    }
    method "aes_gcm" "estado" {
      keys = key_provider.aws_kms.estado
    }
    state {
      method   = method.aes_gcm.estado
      enforced = true # recusa ler/gravar state em claro
    }
    plan {
      method   = method.aes_gcm.estado
      enforced = true
    }
  }
}
