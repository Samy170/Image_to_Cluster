SHELL := /bin/bash

CLUSTER := lab
IMAGE := custom-nginx
TAG := 1.0
FULL_IMAGE := $(IMAGE):$(TAG)
PORT := 8080
NAMESPACE := web
SERVICE := web-svc
DEPLOYMENT := web

.PHONY: help check tools all rebuild build import deploy status open stop-open logs clean

help:
	@echo ""
	@echo "Targets disponibles:"
	@echo "  make check     -> vérifie kubectl/docker/packer/k3d"
	@echo "  make tools     -> installe ansible (user) + export PATH conseillé"
	@echo "  make all       -> build + import + deploy"
	@echo "  make rebuild   -> (après modif index.html) build + import + deploy"
	@echo "  make status    -> pods/services"
	@echo "  make logs      -> logs du pod"
	@echo "  make open      -> port-forward en arrière-plan sur :$(PORT)"
	@echo "  make stop-open -> stop le port-forward"
	@echo "  make clean     -> supprime le déploiement + namespace (ne supprime pas le cluster)"
	@echo ""

check:
	@command -v kubectl >/dev/null || (echo "❌ kubectl introuvable" && exit 1)
	@command -v docker  >/dev/null || (echo "❌ docker introuvable" && exit 1)
	@command -v packer  >/dev/null || (echo "❌ packer introuvable" && exit 1)
	@command -v k3d     >/dev/null || (echo "❌ k3d introuvable" && exit 1)
	@echo "✅ Outils de base OK"

tools:
	@python3 -m pip install --user ansible >/dev/null
	@echo "✅ Ansible installé (user)."
	@echo "👉 Important: dans un nouveau terminal, faire:"
	@echo "   export PATH=\"$$HOME/.local/bin:$$PATH\""
	@export PATH="$$HOME/.local/bin:$$PATH"; ansible-playbook --version | head -n 1

build:
	@echo "==> Packer build"
	@packer init packer
	@packer build packer/nginx.pkr.hcl
	@docker images | grep "$(IMAGE)" || true

import:
	@echo "==> Import image dans k3d"
	@k3d image import $(FULL_IMAGE) -c $(CLUSTER)

deploy:
	@echo "==> Déploiement via Ansible"
	@export PATH="$$HOME/.local/bin:$$PATH"; ansible-playbook ansible/deploy.yml
	@$(MAKE) status

all: check tools build import deploy

rebuild: check tools build import deploy

status:
	@kubectl -n $(NAMESPACE) get pods,svc || true

logs:
	@POD=$$(kubectl -n $(NAMESPACE) get pod -l app=web -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -z "$$POD" ]; then echo "❌ Aucun pod trouvé"; exit 1; fi; \
	echo "==> logs $$POD"; \
	kubectl -n $(NAMESPACE) logs $$POD --tail=100

open:
	@echo "==> Port-forward en arrière-plan sur http://localhost:$(PORT)"
	@$(MAKE) stop-open >/dev/null 2>&1 || true
	@nohup kubectl -n $(NAMESPACE) port-forward svc/$(SERVICE) $(PORT):80 >/tmp/portforward.log 2>&1 & echo $$! > /tmp/portforward.pid
	@sleep 1
	@echo "✅ PID: $$(cat /tmp/portforward.pid)  (logs: /tmp/portforward.log)"

stop-open:
	@if [ -f /tmp/portforward.pid ]; then \
	  PID=$$(cat /tmp/portforward.pid); \
	  kill $$PID >/dev/null 2>&1 || true; \
	  rm -f /tmp/portforward.pid; \
	  echo "✅ Port-forward stoppé"; \
	else \
	  echo "ℹ️ Aucun port-forward à stopper"; \
	fi

clean:
	@echo "==> Nettoyage ressources K8s (namespace $(NAMESPACE))"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true



-------


#Automatisation (Makefile)

- Déploiement complet :
  make all

- Rebuild après modification de `index.html` :
  make rebuild

- Ouvrir l’application (port-forward en arrière-plan) :
  make open

- Voir l’état :
  make status

- Logs du pod :
  make logs

- Stopper le port-forward :
  make stop-open