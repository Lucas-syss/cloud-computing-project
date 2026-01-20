.PHONY: init apply destroy update-hosts validate test status clean

init:
	terraform init

apply: init
	terraform apply -auto-approve -parallelism=1

destroy:
	terraform destroy -auto-approve -parallelism=1

update-hosts:
	./scripts/update_hosts.sh

validate:
	./scripts/validate.sh

test: validate

status:
	minikube profile list

clean:
	minikube delete --all
	rm -rf terraform.tfstate* .terraform/ certs/ .terraform.lock.hcl
