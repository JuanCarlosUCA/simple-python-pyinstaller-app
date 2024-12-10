terraform {
    required_providers {
        docker = {
            source = "kreuzwerker/docker"
            version = "~> 3.0.1"
        }   
    }
}

resource "docker_network" "jenkins" {
  name = "jenkins"
}

# Crear el contenedor Docker-in-Docker
resource "docker_container" "dind" {
  name  = "docker-in-docker"
  image = "docker:19.03.12-dind" 
  restart = "unless-stopped"
  privileged = true  
  
  networks_advanced {
    name = docker_network.jenkins.name
    aliases = ["docker"]
    }

  env = [
    "DOCKER_TLS_CERTDIR=/certs"  # Habilita TLS dentro del contenedor
  ]


  volumes {
    volume_name = docker_volume.jenkins_docker_certs.name
    container_path = "/certs/client"
  }
  
  volumes {
    volume_name = docker_volume.jenkins_data.name
    container_path = "/var/jenkins_home"
  }

    ports {
    internal = 2376
    external = 2376
  }

 command = [
  "--storage-driver",
  "overlay2"
]

}

# Definir los volúmenes del contenedor
resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}

# Crear el contenedor de Jenkins
resource "docker_container" "jenkins" {
  name  = "jenkins"
  image = "jenkins/jenkins:lts" 
  restart = "unless-stopped"     
  privileged = false              

  # Configuración de puertos
  ports {
    internal = 8080  # Puerto de Jenkins
    external = 8081  # Exponer el puerto 8081 en el host
  }

}
