Cet atelier a pour but de montrer pas à pas comment :

1 Construire une image Docker Nginx personnalisée avec Packer

2 Déployer cette image sur un cluster Kubernetes léger (K3d)

3 Déployer l’application via Ansible

4 Rendre l’application accessible depuis un navigateur

Toutes les commandes sont exécutées manuellement, une par une, dans un GitHub Codespace.

Architecture cible
index.html
   ↓
Packer → image Docker custom (Nginx)
   ↓
Import image dans K3d
   ↓
Ansible
   ↓
Kubernetes (Deployment + Service)
   ↓
Navigateur Web

Structure finale du projet
Image_to_Cluster/
├── packer/
│   └── nginx.pkr.hcl
├── ansible/
│   ├── deploy.yml
│   └── k8s/
│       ├── deployment.yml
│       └── service.yml
├── index.html
├── Architecture_cible.png
└── README.md

SÉQUENCE 2 — Création du cluster Kubernetes (K3d)
1 Installer K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
2️ Créer le cluster
k3d cluster create lab --servers 1 --agents 2
3️ Vérifier le cluster
kubectl get nodes

Résultat attendu :
1 server (master)
2 agents (workers)
Tous les nodes en Ready


1️ Créer le contenu HTML
cat > index.html <<'EOF'
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <title>Image to Cluster</title>
</head>
<body>
  <h1>Deployed on K3d</h1>
  <p>Packer → custom image → K3d → Ansible → Kubernetes</p>
</body>
</html>
EOF

2️ Installer Packer
PACKER_VERSION="1.10.3"
curl -LO https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
unzip packer_${PACKER_VERSION}_linux_amd64.zip
sudo mv packer /usr/local/bin/
packer version

3️ Créer le dossier Packer
mkdir -p packer

4️ Créer le fichier packer/nginx.pkr.hcl
cat > packer/nginx.pkr.hcl <<'EOF'
packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.0"
    }
  }
}


source "docker" "nginx" {
  image  = "nginx:alpine"
  commit = true
}


build {
  name    = "custom-nginx"
  sources = ["source.docker.nginx"]


  provisioner "shell" {
    inline = [
      "rm -f /usr/share/nginx/html/index.html"
    ]
  }


  provisioner "file" {
    source      = "index.html"
    destination = "/usr/share/nginx/html/index.html"
  }


  post-processor "docker-tag" {
    repository = "custom-nginx"
    tags       = ["1.0"]
  }
}
EOF

5️ Build de l’image
packer init packer
packer build packer/nginx.pkr.hcl

6️ Vérifier l’image Docker
docker images | grep custom-nginx
Résultat attendu :
custom-nginx   1.0


Étape indispensable
k3d image import custom-nginx:1.0 -c lab

Installer Ansible
python3 -m pip install --user ansible
export PATH="$HOME/.local/bin:$PATH"
ansible --version

2️ Créer les manifests Kubernetes
Deployment
mkdir -p ansible/k8s


cat > ansible/k8s/deployment.yml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: custom-nginx:1.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
EOF


Service
cat > ansible/k8s/service.yml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: web
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
EOF

3️ Créer le playbook Ansible
cat > ansible/deploy.yml <<'EOF'
- name: Deploy custom nginx on k3d
  hosts: localhost
  gather_facts: false
  vars:
    project_dir: /workspaces/Image_to_Cluster


  tasks:
    - name: Ensure namespace exists
      command: kubectl create namespace web
      register: ns
      failed_when: ns.rc != 0 and "AlreadyExists" not in ns.stderr
      changed_when: ns.rc == 0


    - name: Apply deployment
      command: kubectl apply -f ansible/k8s/deployment.yml
      args:
        chdir: "{{ project_dir }}"


    - name: Apply service
      command: kubectl apply -f ansible/k8s/service.yml
      args:
        chdir: "{{ project_dir }}"


    - name: Wait for rollout
      command: kubectl -n web rollout status deployment/web --timeout=120s
EOF

4️ Lancer le déploiement
ansible-playbook ansible/deploy.yml

5️ Vérifier Kubernetes
kubectl -n web get pods,svc

Résultat attendu :
Pod web-xxxxx → Running
Service web-svc

Accès à l’application
Port-forward
kubectl -n web port-forward svc/web-svc 8080:80
Depuis GitHub Codespaces

Onglet PORTS

Port 8080

Rendre le port Public

Ouvrir l’URL
La page Nginx personnalisée s’affiche.

Conclusion
Cette version manuelle permet de comprendre chaque étape du pipeline :
Packer pour la création de l’image
K3d pour le cluster Kubernetes
Ansible pour le déploiement
Kubernetes pour l’exécution applicative
Une version automatisée (Makefile / scripts) pourra ensuite être ajoutée.