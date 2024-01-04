export CHECKPOINT_DISABLE=1
export TF_LOG=TRACE
export TF_LOG_PATH=terraform.log

all: terraform-apply

terraform-init:
	terraform init
	terraform -v

terraform-apply:
	terraform apply \
		| tee terraform-apply.log

terraform-show:
	terraform show

terraform-state-list:
	terraform state list

terraform-graph:
	terraform graph \
		| dot -Tsvg >terraform-graph.svg
	xdg-open terraform-graph.svg

terraform-destroy:
	terraform destroy
