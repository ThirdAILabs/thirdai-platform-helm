job "traefik" {
  datacenters = ["dc1"]

  type = "service"

  constraint {
    attribute = "${node.class}"
    value = "critical_services"
  }

  constraint {
      attribute = "${meta.unique.hostname}"
      distinct_hosts = true
    }

  node_pool = "{{ NODE_POOL }}"

  group "traefik" {
    count = "{{ NUM_CRITICAL_SERVICES_NODES }}"

    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "admin" {
        static = 8080
      }
    }

    service {
      name = "traefik-http"
      provider = "consul"
      port = "http"
      tags = ["traefik"]
      check {
        name     = "Traefik HTTP Health Check"
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "traefik-https"
      provider = "consul"
      port = "https"
      tags = ["traefik"]
      check {
        name     = "Traefik HTTPS Health Check"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "traefik-admin"
      provider = "consul"
      port = "admin"
      tags = ["traefik"]
      check {
        name     = "Traefik Admin Health Check"
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }



    task "server" {
      driver = "docker"

            template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
{% raw %}
{{- with nomadVar "nomad/jobs" -}}
TASK_RUNNER_TOKEN = {{ .task_runner_token }}
{{- end -}}
{% endraw %}
EOF
      }

      config {
        image = "{{ DOCKER_REGISTRY_NAME }}/traefik:v2.10"
        image_pull_timeout = "15m"
        ports = ["admin", "http", "https"]
        args = [
          "--api.dashboard=true",
          
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.websecure.address=:${NOMAD_PORT_https}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_admin}",
          
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://nomad.service.consul:4646",
          "--providers.nomad.endpoint.token=${TASK_RUNNER_TOKEN}",
          
          "--providers.consulcatalog.endpoint.address=172.17.0.1:8500",
          "--providers.consulcatalog=true",
          "--providers.consulcatalog.endpoint.scheme=http",
          "--providers.consulcatalog.exposedByDefault=false",
          
          "--entrypoints.websecure.http.tls=true",
          "--providers.file.filename=/certs/certificates.toml",

          "--ping=true",
          "--ping.entryPoint=web",

          "--log.level=DEBUG"
        ]
        volumes = [
          "{{ SHARE_DIR }}/certs:/certs",
        ]
        auth {
          username = "{{ DOCKER_REGISTRY_USERNAME }}"
          password = "{{ DOCKER_REGISTRY_PASSWORD }}"
          server_address = "{{ DOCKER_REGISTRY_NAME }}"
        }
      }

      resources {
        cpu    = 1000
        memory = 1024

      }
    }
  }
}
