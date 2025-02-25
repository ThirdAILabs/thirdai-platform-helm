job "autoscaler" {
  datacenters = ["dc1"]

  type = "service"

  group "autoscaler" {
    count = 1


    network {
      port "http" {}
    }

    task "autoscaler" {
      driver = "docker"

      config {
        image   = "{{ DOCKER_REGISTRY_NAME }}/nomad-autoscaler:0.3.7"
        image_pull_timeout = "15m"
        command = "nomad-autoscaler"
        ports   = ["http"]
        auth {
          username = "{{ DOCKER_REGISTRY_USERNAME }}"
          password = "{{ DOCKER_REGISTRY_PASSWORD }}"
          server_address = "{{ DOCKER_REGISTRY_NAME }}"
        }

        args = [
          "agent",
          "-config",
          "${NOMAD_TASK_DIR}/config.hcl",
          "-http-bind-address", 
          "0.0.0.0",
          "-http-bind-port",
          "${NOMAD_PORT_http}",
        ]
      }

      template {
        data = <<EOF
{% raw %}
nomad {
  address = "http://{{ env "attr.unique.network.ip-address" }}:4646"
{{- with nomadVar "nomad/jobs" }}
  token = "{{ .task_runner_token }}"
{{- end }}
}

apm "nomad-apm" {
  driver = "nomad-apm"
}

strategy "target-value" {
  driver = "target-value"
}
{% endraw %}
EOF

        destination = "${NOMAD_TASK_DIR}/config.hcl"
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "autoscaler"
        provider = "nomad"
        port = "http"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "3s"
          timeout  = "1s"
        }
      }
    }
  }
}