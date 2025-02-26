job "keycloak" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${node.class}"
    value     = "critical_services"
  }

  constraint {
    attribute     = "${meta.unique.hostname}"
    distinct_hosts = true
  }

  group "keycloak-group" {
    count = "{{ MAJORITY_CRITICAL_SERVICE_NODES }}"

    network {
      port "keycloak-http" {
        to = 8180
      }
      port "keycloak-health" {
        to = 9000
      }
      port "jgroups" {
        static = 7800
      }
    }

    task "keycloak" {
      driver = "docker"
      config {
        image              = "{{ DOCKER_REGISTRY_NAME }}/keycloak:26.0.0"
        image_pull_timeout = "15m"
        ports              = ["keycloak-http", "keycloak-health", "jgroups"]
        args               = ["start", "--http-port=8180", "--debug"]
        auth {
          username       = "{{ DOCKER_REGISTRY_USERNAME }}"
          password       = "{{ DOCKER_REGISTRY_PASSWORD }}"
          server_address = "{{ DOCKER_REGISTRY_NAME }}"
        }
        volumes = [
          "{{ SHARE_DIR }}/keycloak-themes/custom-theme:/opt/keycloak/themes/custom-theme",
          "{{ SHARE_DIR }}/keycloak-themes/cache-ispn-jdbc-ping.xml:/opt/keycloak/conf/cache-ispn-jdbc-ping.xml"
        ]
      }

      env {
        KC_HTTP_ENABLED                 = "true"
        KC_HTTP_RELATIVE_PATH           = "/keycloak"
        KC_HOSTNAME_ADMIN               = "https://localhost/keycloak"
        KC_HOSTNAME                     = "{{ PUBLIC_KEYCLOAK_SERVER_URL }}"
        KC_HOSTNAME_BACKCHANNEL_DYNAMIC = "true"
        KC_HOSTNAME_DEBUG               = "true"
        KC_PROXY_HEADERS                = "xforwarded"

        # Database
        KC_DB         = "{{ KC_DB }}"
        KC_DB_URL     = "{{ KC_DB_URL }}"
        KC_DB_USERNAME= "{{ KC_DB_USERNAME }}"
        KC_DB_PASSWORD= "{{ KC_DB_PASSWORD }}"

        KC_BOOTSTRAP_ADMIN_USERNAME = "temp_admin"
        KC_BOOTSTRAP_ADMIN_PASSWORD = "password"

        KC_LOG_CONSOLE_LEVEL = "debug"
        KC_HEALTH_ENABLED    = "true"

        KC_CACHE_CONFIG_FILE          = "cache-ispn-jdbc-ping.xml"
        KC_CACHE_STACK                = "postgres-jdbc-ping-tcp"
        JGROUPS_DISCOVERY_EXTERNAL_IP = "${NOMAD_IP_keycloak-http}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name     = "keycloak"
        port     = "keycloak-http"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.keycloak-http.rule=PathPrefix(`/keycloak`)",
          "traefik.http.routers.keycloak-http.entrypoints=websecure",
          "traefik.http.routers.keycloak-http.service=keycloak-service",
          # Middleware for HTTPS redirect for the main service
          "traefik.http.middlewares.keycloak-redirect-https.redirectscheme.scheme=https",
          "traefik.http.routers.keycloak-http.middlewares=keycloak-redirect-https",
          "traefik.http.services.keycloak-service.loadbalancer.server.scheme=http",

          # New router for reset credentials endpoint with rate limiting middleware
          "traefik.http.routers.keycloak-reset.rule=PathPrefix(`/keycloak/realms/ThirdAI-Platform/login-actions/reset-credentials`)",
          "traefik.http.routers.keycloak-reset.entrypoints=websecure",
          "traefik.http.routers.keycloak-reset.middlewares=reset-limit",

          # Rate limiting middleware settings: allow 4 requests per 4 minutes per IP
          "traefik.http.middlewares.reset-limit.ratelimit.average=4",
          "traefik.http.middlewares.reset-limit.ratelimit.burst=4",
          "traefik.http.middlewares.reset-limit.ratelimit.period=4m"
        ]

        check {
          name     = "Keycloak Health Check"
          type     = "http"
          port     = "keycloak-health"
          path     = "/keycloak/health/ready"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit = 1
            grace = "1m"
          }
        }
      }

      service {
        name     = "keycloak-health"
        port     = "keycloak-health"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.keycloak-health.rule=PathPrefix(`/keycloak/health`)",
          "traefik.http.routers.keycloak-health.priority=20",
          "traefik.http.routers.keycloak-health.entrypoints=web",
          "traefik.http.routers.keycloak-health.service=keycloak-health-service",
          "traefik.http.services.keycloak-health-service.loadbalancer.server.scheme=http"
        ]
        check {
          name     = "Keycloak Health Check"
          type     = "http"
          port     = "keycloak-health"
          path     = "/keycloak/health/ready"
          interval = "5s"
          timeout  = "2s"
        }
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
