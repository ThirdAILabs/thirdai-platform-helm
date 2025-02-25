# Allow reading, creating, updating, and listing all secrets
path "secrets/data/*" {
  capabilities = ["read", "create", "update", "list"]
}

path "secrets/metadata/*" {
  capabilities = ["read", "create", "update", "list"]
}

path "sys/*" {
  capabilities = ["read"]
}

path "pki/*" {
  capabilities = ["create", "read", "update", "list"]
}