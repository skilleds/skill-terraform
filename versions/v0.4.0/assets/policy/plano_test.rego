package main

import rego.v1

# Vermelho primeiro: cada caso abaixo prova que a política reprova o que deve e aprova o que pode.
plano_ok := {"resource_changes": [{
	"address": "module.app.hcloud_server.this",
	"type": "hcloud_server",
	"change": {"actions": ["create"], "after": {"labels": {"owner": "x", "project": "p", "managed_by": "opentofu", "env": "hml"}}},
}]}

plano_sem_marcas := {"resource_changes": [{
	"address": "module.app.hcloud_server.this",
	"type": "hcloud_server",
	"change": {"actions": ["create"], "after": {"labels": {"owner": "x"}}},
}]}

plano_destroy_critico := {"resource_changes": [{
	"address": "hcloud_volume.dados",
	"type": "hcloud_volume",
	"change": {"actions": ["delete", "create"], "after": {"labels": {"owner": "x", "project": "p", "managed_by": "opentofu", "env": "prd"}}},
}]}

test_plano_ok_passa if {
	count(deny) == 0 with input as plano_ok
}

test_sem_marcas_reprova if {
	count(deny) == 1 with input as plano_sem_marcas
}

test_destroy_critico_reprova if {
	count(deny) == 1 with input as plano_destroy_critico
}
