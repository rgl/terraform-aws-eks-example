export CHECKPOINT_DISABLE=1
export TF_LOG=TRACE
export TF_LOG_PATH=terraform.log

all: terraform-apply

terraform-init:
	terraform init
	terraform -v

terraform-apply:
	rm -f terraform-apply.log
	terraform apply \
		| tee terraform-apply.log

terraform-show:
	terraform show

terraform-state-list:
	terraform state list

terraform-graph:
	terraform graph \
		| dot -Tsvg >terraform-graph.svg
	inkscape terraform-graph.svg

terraform-graph-plan-destroy:
	terraform plan -destroy -out=tfplan -input=false
	terraform graph -plan=tfplan -type=plan-destroy \
		| dot -Tsvg >terraform-graph-plan-destroy.svg
	inkscape terraform-graph-plan-destroy.svg

terraform-destroy:
	rm -f terraform-destroy.log
	terraform destroy \
		| tee terraform-destroy.log
