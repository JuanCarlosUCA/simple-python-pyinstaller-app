
# Crear una red Docker para los contenedores
resource "docker_network" "jenkins_network" {
  name = "jenkins_network"
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
    external = 8080  # Exponer el puerto 8080 en el host
  }


  # Conexión a la red Docker
  networks_advanced {
    name = docker_network.jenkins_network.name
  }

}
