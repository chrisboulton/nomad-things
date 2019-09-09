job "backend-service-1" {
  datacenters = ["dc1"]
  type = "service"
  group "api" {
    count = 2
    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    update {
      max_parallel     = 1
      canary           = 1
      min_healthy_time = "30s"
      healthy_deadline = "5m"
      auto_revert      = true
      auto_promote     = false
    }

    service {
      name = "backend-service-1"
      port = "80"
      canary_tags = ["canary"]

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "http-1"
              local_bind_port = 4140
            }
            upstreams {
              destination_name = "grpc"
              local_bind_port = 4142
            }
          }
        }
      }

      check {
        type = "http"
        port = "http"
        path = "/"
        interval = "10s"
        timeout = "2s"
      }
    }

    task "server" {
      driver = "docker"
      config {
        image = "nginx:latest"
        volumes = [
          "www-data:/usr/share/nginx/html"
        ]
      }

      resources {
        cpu = 150
        memory = 128
      }

      template {
        destination = "www-data/index.html"
        data = "greetings this is backend-service-1"
      }
    }
  }
}
