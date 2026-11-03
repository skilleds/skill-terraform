# Política como código do PLAN (conftest/OPA). Entrada: `tofu show -json plano.tfplan`.
# Uso:  conftest test --policy assets/policy plano.json
package main

import rego.v1

# Chaves de rastreio obrigatórias em todo recurso que aceita labels/tags.
obrigatorias := {"owner", "project", "managed_by", "env"}

# Tipos cujo DESTROY em prd exige decisão humana explícita (aprovação separada, não o apply padrão).
criticos := {
	"hcloud_server", "hcloud_volume", "hcloud_primary_ip", "hcloud_floating_ip",
	"aws_db_instance", "aws_rds_cluster", "aws_s3_bucket", "aws_dynamodb_table", "aws_kms_key",
	"cloudflare_zone", "github_repository",
}

# Ações que criam ou alteram (delete puro não precisa de tag).
muda(rc) if {
	some a in rc.change.actions
	a in {"create", "update"}
}

# labels (Hetzner) ou tags (AWS e outros); o que existir.
marcas(after) := object.union(object.get(after, "labels", {}), object.get(after, "tags_all", object.get(after, "tags", {}))) if {
	after != null
} else := {}

deny contains msg if {
	some rc in input.resource_changes
	muda(rc)
	after := rc.change.after
	is_object(after)
	some campo in {"labels", "tags"}
	object.keys(after)[_] == campo # o recurso suporta a marca
	faltando := obrigatorias - object.keys(marcas(after))
	count(faltando) > 0
	msg := sprintf("%s: faltam marcas obrigatórias %v", [rc.address, sort_set(faltando)])
}

deny contains msg if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
	rc.type in criticos
	msg := sprintf("%s: destroy/replace de recurso crítico exige aprovação explícita (ADR/humano)", [rc.address])
}

sort_set(s) := sort([x | some x in s])
