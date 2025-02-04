resource "random_string" "unique_suffix" {
  length  = 6
  upper   = false
  special = false
}
