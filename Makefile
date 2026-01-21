.PHONY: init apply-all destroy-all update-hosts clean status

# Initialize and create workspaces
init:
	terraform init -upgrade
	-terraform workspace new airbnb
	-terraform workspace new nike
	-terraform workspace new mcdonalds

# Apply a specific client (Usage: make apply client=airbnb)
apply:
	@if [ -z "$(client)" ]; then echo "Error: Please specify client (e.g., make apply client=airbnb)"; exit 1; fi
	terraform workspace select $(client)
	terraform apply -auto-approve -parallelism=1
	./scripts/update_hosts.sh

# Apply ALL clients sequentially
apply-all: init
	$(MAKE) apply client=airbnb
	$(MAKE) apply client=nike
	$(MAKE) apply client=mcdonalds

# Destroy a specific client
destroy:
	@if [ -z "$(client)" ]; then echo "Error: Please specify client (e.g., make destroy client=airbnb)"; exit 1; fi
	terraform workspace select $(client)
	terraform destroy -auto-approve -parallelism=1

# Destroy ALL
destroy-all:
	terraform workspace select airbnb && terraform destroy -auto-approve
	terraform workspace select nike && terraform destroy -auto-approve
	terraform workspace select mcdonalds && terraform destroy -auto-approve
	minikube delete --all

update-hosts:
	./scripts/update_hosts.sh

status:
	minikube profile list

clean:
	rm -rf terraform.tfstate* .terraform/ certs/ .terraform.lock.hcl