terraform {
    required_providers {
        docker = {
            source = "kreuzwerker/docker"
            version = "~> 3.0.1"
        }   
    }
}

provider "docker"{
  host = "npipe:////.//pipe//docker_engine"
}

resource "docker_network" "jenkins" {
  name = "jenkins"
}

# Definir los volúmenes del contenedor
resource "docker_volume" "jenkins_docker_certs" {
  name = "jenkins-docker-certs"
}

resource "docker_volume" "jenkins_data" {
  name = "jenkins-data"
}


# Crear el contenedor Docker-in-Docker
resource "docker_container" "dind" {
  name  = "docker-in-docker"
  image = "docker:dind" 
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


# Crear el contenedor de Jenkins
resource "docker_container" "jenkins_blueocean" {
  name  = "jenkins-blueocean"
  image = "myjenkins-blueocean" 
  restart = "on-failure"
  privileged = false              

  networks_advanced {
    name = docker_network.jenkins.name
  }

  ports {
    internal = 8080
    external = 8080
  }

  ports {
    internal = 50000
    external = 50000
  }

  env = [
    "DOCKER_HOST=tcp://docker:2376",
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1",
  ]

  volumes {
    volume_name    = docker_volume.jenkins_data.name
    container_path = "/var/jenkins_home"
  }

  volumes {
    volume_name    = docker_volume.jenkins_docker_certs.name
    container_path = "/certs/client"
    read_only      = true
  }

}
