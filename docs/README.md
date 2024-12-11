ENTREGABLE 3 VIRTUALIZACIÓN DE SISTEMAS
JUAN CARLOS FERNÁNDEZ PIÑA

1) Copiar (Fork) el repositorio simple-python-pynstaller-app

Vamos a " https://github.com/jenkins-docs/simple-python-pyinstaller-app "
Pulsamos el botón verde " <> Code" y clonamos el repositorio a nuestro propio Git.


2) Crear archivo Terraform con la configuración de Dind y Jenkins

Creamos un archivo .tf en el que ponemos la configuración de los servicios de Docker in Docker y Jenkins que necesitamos, teniendo este código:

```
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

```

3) Creamos el archivo Dockerfile con la imagen oficial de Jenkins de Docker:

```
FROM jenkins/jenkins:2.479.2-jdk17
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
https://download.docker.com/linux/debian \
$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow token-macro json-path-api"
```

4) Creamos el archivo Jenkinsfile indicado en el entregable:

```
pipeline {
    agent none
    options {
        skipStagesAfterUnstable()
    }
    stages {
        stage('Build') {
            agent {
                docker {
                    image 'python:3.12.0-alpine3.18'
                }
            }
            steps {
                sh 'python -m py_compile sources/add2vals.py sources/calc.py'
                stash(name: 'compiled-results', includes: 'sources/*.py*')
            }
        }
        stage('Test') {
            agent {
                docker {
                    image 'qnib/pytest'
                }
            }
            steps {
                sh 'py.test --junit-xml test-reports/results.xml sources/test_calc.py'
            }
            post {
                always {
                    junit 'test-reports/results.xml'
                }
            }
        }
        stage('Deliver') {
            agent any
            environment {
                VOLUME = '$(pwd)/sources:/src'
                IMAGE = 'cdrx/pyinstaller-linux:python2'
            }
            steps {
                dir(path: env.BUILD_ID) {
                    unstash(name: 'compiled-results')
                    sh "docker run --rm -v ${VOLUME} ${IMAGE} 'pyinstaller -F add2vals.py'"
                }
            }
            post {
                success {
                    archiveArtifacts "${env.BUILD_ID}/sources/dist/add2vals"
                    sh "docker run --rm -v ${VOLUME} ${IMAGE} 'rm -rf build dist'"
                }
            }
        }
    }
}
```

Una vez tenemos los archivos de configuración necesarios, abrimos la consola de comandos con el directorio donde tenemos estos archivos, y ejecutamos las siguientes líneas:

docker build -t myjenkins-blueocean .

terraform init
terraform apply

docker ps

docker exec -it jenkins-blueocean bash

Abrimos localhost:8080

cat /var/jenkins_home/secrets/initialAdminPassword

Copiamos la contraseña que nos genera, y podremos abrir la web de Jenkins.