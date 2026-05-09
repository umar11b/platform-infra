PROJECT_ID           := gke-infrastructure-493002
ZONE                 := us-central1-a
PLATFORM_CONFIG_DIR  ?= $(HOME)/repos/platform-config

# Detect the Pi's current public IP (run this on the Pi itself)
PI_IP ?= $(shell curl -4 -s --max-time 5 ifconfig.me)

.PHONY: init plan up down rebuild fmt validate kubeconfig bootstrap argocd-pw

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

rebuild: down up bootstrap

kubeconfig:
	gcloud container clusters get-credentials platform-cluster \
		--zone $(ZONE) --project $(PROJECT_ID)

bootstrap: kubeconfig
	@echo "==> Creating argocd namespace"
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@echo "==> Installing Argo CD (stable)"
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "==> Waiting for argocd-server (up to 5m)..."
	kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
	kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
	@echo "==> Applying root app-of-apps"
	kubectl apply -f $(PLATFORM_CONFIG_DIR)/apps/root.yaml
	@echo ""
	@echo "Bootstrap complete. Argo CD is reconciling add-ons."
	@echo "UI:       kubectl -n argocd port-forward svc/argocd-server 8080:443"
	@echo "Password: make argocd-pw"

argocd-pw:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d && echo
