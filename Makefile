tfvars := ${SECRETS_DIR}/terrform.tfvars
params_yaml := ${SECRETS_DIR}/params.yaml

cluster_name := $(shell yq .cluster_name $(params_yaml))

define TFVARS
cluster_name         = "$(cluster_name)"
domain               = "$(shell yq e .domain $(params_yaml))"
project_root         = "$(PROJECT_DIR)"

cluster_image_name   = "$(shell yq .cluster_image_name $(params_yaml))"

controllers = "$(shell yq .cluster.controllers $(params_yaml))"
workers     = "$(shell yq .cluster.workers $(params_yaml))"

cpus        = "$(shell yq .node.cpus $(params_yaml))"
memory      = "$(shell yq .node.memory $(params_yaml))"
disk_size   = "$(shell yq .node.disk_size $(params_yaml))"

kubernetes_cidr       = "$(shell yq .cluster.kubernetes_cidr $(params_yaml))"
load_balancer_cidr    = "$(shell yq .cluster.load_balancer_cidr $(params_yaml))"
control_plane_mac     = $(shell yq --output-format json .cluster.control_plane_mac $(params_yaml))
pod_cidr              = "$(shell yq '.cluster.pod_cidr // "10.244.0.0/16"' $(params_yaml))"
pod_cidr_v6           = "$(shell yq '.cluster.pod_cidr_v6 // "fd00:10:244::/48"' $(params_yaml))"
service_cidr          = "$(shell yq '.cluster.service_cidr // "10.96.0.0/12"' $(params_yaml))"
service_cidr_v6       = "$(shell yq '.cluster.service_cidr_v6 // "fd00:10:96::/112"' $(params_yaml))"

nutanix_username          = "$(shell yq .nutanix.username $(params_yaml))"
nutanix_password          = "$(shell sops --decrypt --extract '["nutanix"]["password"]' $(params_yaml))"
nutanix_prism_central     = "$(shell yq .nutanix.prism_central $(params_yaml))"
nutanix_cluster_name      = "$(shell yq .nutanix.cluster $(params_yaml))"
nutanix_storage_container = "$(shell yq .nutanix.storage_container $(params_yaml))"
kubernetes_subnet         = "$(shell yq .nutanix.subnets.kubernetes $(params_yaml))"
workload_subnet           = "$(shell yq .nutanix.subnets.workload $(params_yaml))"

nutanix_files_server      = "$(shell yq .nutanix.files.server $(params_yaml))"
nutanix_files_export      = "$(shell yq .nutanix.files.export $(params_yaml))"
endef

.PHONY: tfvars
tfvars: $(tfvars)

export TFVARS
$(tfvars): $(params_yaml)
	@echo "$$TFVARS" > $@

.PHONY: init
init: $(tfvars)
	@(cd $(SOURCE_DIR)/terraform && terraform init)

.PHONY: nodes
nodes: $(tfvars)
	@(cd ${SOURCE_DIR}/terraform && terraform apply -var-file $(tfvars) --auto-approve)

.PHONY: cluster
cluster: nodes
	@cd ${SOURCE_DIR}/terraform && terraform output -raw talosconfig > ${SECRETS_DIR}/talosconfig
	@cd ${SOURCE_DIR}/terraform && terraform output -raw kubeconfig > ${SECRETS_DIR}/kubeconfig

.PHONY: test
test: $(tfvars)
	@(cd ${SOURCE_DIR}/terraform && terraform plan -var-file $(tfvars))

.PHONY: destroy
destroy: $(tfvars)
	@(cd ${SOURCE_DIR}/terraform && terraform destroy -var-file $(tfvars) --auto-approve)

clean:
	@rm $(tfvars)

.PHONY: encrypt
encrypt: 
	@sops --encrypt --in-place $(params_yaml)

.PHONY: decrypt
decrypt: 
	@sops --decrypt --in-place $(params_yaml)
