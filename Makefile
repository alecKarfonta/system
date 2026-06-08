# =============================================================================
#  Homelab GPU Cluster - friendly command interface
#  Run 'make' or 'make help' to see everything.
# =============================================================================
SHELL := /bin/bash
S := ./scripts

.DEFAULT_GOAL := help

.PHONY: help preflight server join-server agent add-node remove-node \
        label-gpus install-driver install-driver-node fix-cni status stack dashboard ui cockpit cockpit-ui cockpit-demo cli kubeconfig smoke uninstall config \
        registry registry-nodes registry-secret registry-verify \
        plateforge-images plateforge-images-sync plateforge-images-resolve \
        app-validate app-deploy app-diff app-status app-delete app-verify app-register \
        app-init app-list app-validate-all

help: ## Show this help
	@echo ""
	@echo "  Homelab GPU Cluster"
	@echo "  ==================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-14s\033[0m %s\n",$$1,$$2}'
	@echo ""
	@echo "  Typical first run (on the control-plane machine):"
	@echo "    make config        # then edit config/cluster.env"
	@echo "    make preflight"
	@echo "    make server"
	@echo "    make kubeconfig"
	@echo "    make stack"
	@echo "    make label-gpus"
	@echo "    make status"
	@echo ""

config: ## Create config/cluster.env from the template
	@if [[ -f config/cluster.env ]]; then \
	  echo "config/cluster.env already exists — not overwriting."; \
	else \
	  cp config/cluster.env.example config/cluster.env; \
	  echo "Created config/cluster.env — open it and edit SERVER_HOST etc."; \
	fi

preflight: ## Check this machine is ready (run on every node before joining)
	@$(S)/preflight.sh

server: ## Install the FIRST control-plane node (run on that machine)
	@$(S)/install-server.sh

join-server: ## Join as an ADDITIONAL control-plane node (needs JOIN_TOKEN=...)
	@$(S)/join-server.sh

agent: ## Join as a GPU worker (needs JOIN_TOKEN=...)
	@$(S)/install-agent.sh

add-node: ## (on a server) Print the command to add a new node. ROLE=worker|server
	@$(S)/add-node.sh $(ROLE)

remove-node: ## (on a server) Gracefully remove a node. Usage: make remove-node NODE=name
	@$(S)/remove-node.sh

label-gpus: ## Auto-tag nodes by GPU + CPU tier (training/inference/…, cheap/standard/performance)
	@$(S)/label-gpus.sh

install-driver: ## Install NVIDIA host driver on THIS machine
	@$(S)/install-nvidia-driver.sh

install-driver-node: ## SSH install driver on a node. NODE=name or HOST=ip [USER=alec]
	@$(S)/install-driver-node.sh

fix-cni: ## Fix NotReady / cni plugin not initialized on THIS machine
	@$(S)/fix-cni.sh

status: ## Show the whole fleet: nodes, GPUs, tiers, workloads
	@$(S)/cluster-status.sh

stack: ## Install GPU Operator + DRA + Longhorn + monitoring (Helm)
	@$(S)/bootstrap-stack.sh

registry: ## Install private container registry (Longhorn-backed, port 30500)
	@$(S)/registry.sh install

registry-nodes: ## Configure all k3s nodes to pull from the homelab registry
	@$(S)/registry.sh nodes

registry-secret: ## Create imagePullSecret in a namespace. Usage: make registry-secret NS=plateforge
	@$(S)/registry.sh secret $(NS)

registry-verify: ## Test HTTPS registry API and crictl pull on this node
	@$(S)/registry.sh verify

plateforge-images: ## Point plateforge at local registry if present, else GHCR
	@$(S)/plateforge-images.sh apply

plateforge-images-sync: ## Copy plateforge images from GHCR into homelab registry, then apply
	@$(S)/plateforge-images.sh sync

plateforge-images-resolve: ## Show which image refs plateforge would use
	@$(S)/plateforge-images.sh resolve

app-validate: ## Validate app contract. Usage: make app-validate APP=plateforge
	@test -n "$(APP)" || { echo "Usage: make app-validate APP=<name>"; exit 1; }
	@$(S)/validate-app.sh "$(APP)"

app-deploy: ## Deploy registered app. Usage: make app-deploy APP=plateforge
	@test -n "$(APP)" || { echo "Usage: make app-deploy APP=<name>"; exit 1; }
	@$(S)/deploy-app.sh "$(APP)" deploy

app-diff: ## Diff app manifests vs cluster. Usage: make app-diff APP=plateforge
	@test -n "$(APP)" || { echo "Usage: make app-diff APP=<name>"; exit 1; }
	@$(S)/deploy-app.sh "$(APP)" diff

app-status: ## Show app namespace resources. Usage: make app-status APP=plateforge
	@test -n "$(APP)" || { echo "Usage: make app-status APP=<name>"; exit 1; }
	@$(S)/deploy-app.sh "$(APP)" status

app-delete: ## Remove app from cluster. Usage: make app-delete APP=plateforge
	@test -n "$(APP)" || { echo "Usage: make app-delete APP=<name>"; exit 1; }
	@$(S)/deploy-app.sh "$(APP)" delete

app-verify: ## Run app health checks. Usage: make app-verify APP=plateforge
	@test -n "$(APP)" || { echo "Usage: make app-verify APP=<name>"; exit 1; }
	@$(S)/deploy-app.sh "$(APP)" verify

app-register: ## Register app repo. Usage: make app-register REPO=~/git/myapp
	@test -n "$(REPO)" || { echo "Usage: make app-register REPO=<path>"; exit 1; }
	@$(S)/register-app.sh "$(REPO)"

app-init: ## Scaffold new app. Usage: make app-init NAME=myapp REPO=~/git/myapp [PORT=8080]
	@test -n "$(NAME)" && test -n "$(REPO)" || { echo "Usage: make app-init NAME=<name> REPO=<path> [PORT=8080] [CPU_TIER=cheap]"; exit 1; }
	@NAME="$(NAME)" REPO="$(REPO)" PORT="$(PORT)" CPU_TIER="$(CPU_TIER)" GHCR_ORG="$(GHCR_ORG)" \
		REGISTER="$(REGISTER)" $(S)/init-app.sh

app-list: ## List registered apps and cluster status
	@$(S)/list-apps.sh list

app-validate-all: ## Validate all registered app contracts
	@$(S)/list-apps.sh validate-all

dashboard: ## Install Headlamp, a web GUI for the cluster (run once)
	@$(S)/dashboard.sh install

ui: ## Open the Headlamp web GUI + print your login token
	@$(S)/dashboard.sh open

cockpit: ## Install/update the Fleet Cockpit (GPU-centric management GUI)
	@$(S)/cockpit.sh install

cockpit-ui: ## Open the Fleet Cockpit
	@$(S)/cockpit.sh open

cockpit-demo: ## Preview the Cockpit locally with fake data
	@$(S)/cockpit.sh demo

cli: ## Install the 'homelab' CLI to /usr/local/bin
	@sudo ln -sf $(CURDIR)/cli/homelab /usr/local/bin/homelab && echo "Installed: homelab (try 'homelab discover')"

kubeconfig: ## (on a server) Write ~/.kube/config so plain kubectl works
	@$(S)/kubeconfig.sh

smoke: ## Run a GPU smoke test and show its output
	@kubectl apply -f manifests/examples/01-gpu-smoke-test.yaml
	@echo "Waiting for the test pod to finish..."
	@kubectl wait --for=condition=complete job/gpu-smoke-test --timeout=120s || \
	  kubectl wait --for=condition=failed job/gpu-smoke-test --timeout=10s || true
	@echo "----- nvidia-smi output -----"
	@kubectl logs job/gpu-smoke-test || true
	@kubectl delete -f manifests/examples/01-gpu-smoke-test.yaml >/dev/null 2>&1 || true

uninstall: ## Remove k3s from THIS machine (destructive)
	@$(S)/uninstall.sh
