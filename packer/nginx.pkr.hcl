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
