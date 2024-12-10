terraform {
    required_providers {
        docker = {
            source = "kreuzwerker/docker"
            version = "~> 3.0.1"
        }   
    }
}
# Crear una red de Docker para que los contenedores se comuniquen entre sí
resource "docker_network" "dind_network" {
  name = "dind_network"
}

# Crear el contenedor Docker-in-Docker
resource "docker_container" "dind" {
  name  = "docker-in-docker"
  image = "docker:19.03.12-dind"  # Imagen oficial de Docker-in-Docker
  restart = "unless-stopped"
  privileged = true  # Necesario para ejecutar Docker dentro de Docker

  # Conexión a la red Docker
  networks_advanced {
    name = docker_network.dind_network.name
  }
    ports {
    internal = 80
    external = 8000
  }

}

resource "docker_container" "dind_client" {
  name  = "dind-client"
  image = "docker:19.03.12"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.dind_network.name
  }

  # Conectarse al contenedor Docker-in-Docker
  command = "docker --host tcp://dind:8000 ps"  # Este contenedor ejecuta comandos Docker contra el contenedor DIND
}
