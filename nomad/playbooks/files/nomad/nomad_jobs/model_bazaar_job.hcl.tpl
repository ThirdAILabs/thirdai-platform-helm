job "modelbazaar" {
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

  group "modelbazaar" {
    count = "{{ MAJORITY_CRITICAL_SERVICE_NODES }}"

    network {
       port "modelbazaar-http" {
         to = 80
       }
    }

    service {
      name = "modelbazaar"
      port = "modelbazaar-http"
      provider = "consul"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.modelbazaar-http.rule=(PathPrefix(`/api`) && !PathPrefix(`/api/auth`))",
        "traefik.http.routers.modelbazaar-http.priority=10",
        "traefik.http.middlewares.request-size-limit.buffering.maxRequestBodyBytes=524288000",
        "traefik.http.middlewares.request-size-limit.buffering.memRequestBodyBytes=1048576",
        "traefik.http.routers.modelbazaar-http.middlewares=request-size-limit",
      ]
      check {
        name     = "Modelbazaar Health Check"
        type     = "http"
        port     = "modelbazaar-http"
        path     = "/api/v2/health"
        interval = "5s"
        timeout  = "2s"

        check_restart {
          limit = 1
          grace = "1m"
        }
      }
    }

    task "server" {

      driver = "docker"

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data        = <<EOF
{% raw %}
{{- with nomadVar "nomad/jobs" -}}
TASK_RUNNER_TOKEN = {{ .task_runner_token }}
DATABASE_URI = {{ .sql_uri }}
{{- end -}}
{% endraw %}
EOF
      }

      env {
        INGRESS_HOSTNAME = "http://{{ PUBLIC_SERVER_IP }}/"
        PRIVATE_MODEL_BAZAAR_ENDPOINT = "http://traefik-http.service.consul/"
        LICENSE_PATH = "/model_bazaar/license/ndb_enterprise_license.json"
        NOMAD_ENDPOINT = "http://172.17.0.1:4646/"
        SHARE_DIR = "{{ SHARE_DIR }}"
        JWT_SECRET = "{{ JWT_SECRET }}"
        ADMIN_USERNAME =  "{{ ADMIN_USERNAME }}"
        ADMIN_MAIL = "{{ ADMIN_MAIL }}"
        ADMIN_PASSWORD = "{{ ADMIN_PASSWORD }}"
        AUTOSCALING_ENABLED = "{{ AUTOSCALING_ENABLED | string | lower }}"
        AUTOSCALER_MAX_COUNT = "{{ AUTOSCALER_MAX_COUNT }}"
        GENAI_KEY = "{{ GENAI_KEY }}"
        IDENTITY_PROVIDER = "{{ IDENTITY_PROVIDER }}"
        KEYCLOAK_SERVER_URL = "{{ KEYCLOAK_SERVER_URL }}"
        USE_SSL_IN_LOGIN = "{{ USE_SSL_IN_LOGIN }}"
        {% if USE_LOCAL_REGISTRY %}
        DOCKER_REGISTRY = "{{ DOCKER_REGISTRY_NAME }}"
        DOCKER_USERNAME = "{{ DOCKER_REGISTRY_USERNAME }}"
        DOCKER_PASSWORD = "{{ DOCKER_REGISTRY_PASSWORD }}"
        TAG = "{{ THIRDAI_PLATFORM_VERSION }}"
        {% endif %}
        TASK_RUNNER_TOKEN = "${TASK_RUNNER_TOKEN}"
        DATABASE_URI = "${DATABASE_URI}"
        AIRGAPPED = "${AIRGAPPED}"
        GRAFANA_DB_URL = "{{ GRAFANA_DB_URL }}"
        MAJORITY_CRITICAL_SERVICE_NODES = "{{ MAJORITY_CRITICAL_SERVICE_NODES }}"
      }

      config {
        image = "{{ DOCKER_REGISTRY_NAME }}/thirdai_platform_{{ PLATFORM_IMAGE_BRANCH }}:{{ THIRDAI_PLATFORM_VERSION }}"
        image_pull_timeout = "45m"
        ports = ["modelbazaar-http"]
        group_add = ["4646"]
        auth {
          username = "{{ DOCKER_REGISTRY_USERNAME }}"
          password = "{{ DOCKER_REGISTRY_PASSWORD }}"
          server_address = "{{ DOCKER_REGISTRY_NAME }}"
        }
        volumes = [
          "{{ SHARE_DIR }}:/model_bazaar"
        ]
      }

      resources {
        cpu    = 1000
        memory = 1000

      }

    }

    restart {
        attempts = 3
        interval = "10m"
        delay    = "2s"
        mode     = "fail"
      }
  }
}
