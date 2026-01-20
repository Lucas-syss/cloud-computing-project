variable "clients" {
  description = "Map of clients and their environments"
  type = map(object({
    environments = list(string)
  }))
  default = {
    "airbnb" = {
      environments = ["dev", "prod"]
    }
    "nike" = {
      environments = ["dev", "qa", "prod"]
    }
    "mcdonalds" = {
      environments = ["dev", "qa", "beta", "prod"]
    }
  }
}
