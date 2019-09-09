job "web-app" {
  datacenters = ["dc1"]
  type = "system"
  group "web" {
    network {
      mode = "bridge"
      port "http" {
        to = 8080
        static = 80
      }
    }

    service {
      name = "web-app"
      port = "http"

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
        image = "ruby:latest"
        work_dir = "/usr/src"
        command = "ruby"
        args = ["/usr/src/app.rb"]
        volumes = [
          "src:/usr/src"
        ]
      }

      resources {
        cpu = 150
        memory = 128
      }

      template {
        destination = "src/app.rb"
        data = <<EOF
require 'webrick'
require 'net/http'
require 'json'

server = WEBrick::HTTPServer.new :Port => 8080
server.mount_proc '/' do |request, response|
  body = []
  body << '<h1>Hello from the web app!</h1>'
  ['backend-service-1', 'backend-service-2'].each do |backend|
    body << "<h2>Response from #{backend}:</h2><pre>"
    begin
      http = Net::HTTP.new('127.0.0.1', 4140)
      req = Net::HTTP::Get.new('/')
      req['host'] = "#{backend}.linkerd"
      res = http.request(req)
      body << "<strong>#{res.code}</strong>"
      body << "\n"
      res.to_hash.each do |k, v|
        body << "#{k}: #{v.join}\n"
      end
      body << "\n"
      body << res.body
    rescue => e
      body << e
    end
    body << '</pre>'
  end
  response.content_type = 'text/html'
  response.body = body.join
end

trap('INT') { server.shutdown }
server.start
EOF
      }
    }
  }
}
