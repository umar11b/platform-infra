PROJECT_ID := gke-infrastructure-493002
ZONE       := us-central1-a

# Detect the Pi's current public IP (run this on the Pi itself)
PI_IP ?= $(shell curl -s --max-time 5 ifconfig.me)

.PHONY: init plan up down rebuild fmt validate kubeconfig

init:
	terraform init

fmt:
	terraform fmt -recursive

validate: init
	terraform validate

plan:
	@echo "Pi public IP: $(PI_IP)"
	terraform plan -var="pi_public_ip=$(PI_IP)"

up:
	@echo "Pi public IP: $(PI_IP)"
	@START=$$(date +%s); \
	terraform apply -auto-approve -var="pi_public_ip=$(PI_IP)"; \
	END=$$(date +%s); \
	echo "Cluster up in $$(( END - START ))s"

down:
	@START=$$(date +%s); \
	terraform destroy -auto-approve -var="pi_public_ip=$(PI_IP)"; \
	END=$$(date +%s); \
	echo "Cluster down in $$(( END - START ))s"

rebuild: down up

kubeconfig:
	gcloud container clusters get-credentials platform-cluster \
		--zone $(ZONE) --project $(PROJECT_ID)
