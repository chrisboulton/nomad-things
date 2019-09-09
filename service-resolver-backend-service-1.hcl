kind = "service-resolver"
name = "backend-service-1"
default_subset = "not-canary"
subsets = {
  "not-canary" {
    filter = "Service.ServiceTags not contains canary"
    only_passing = true
  }
  "canary" {
    filter = "Service.ServiceTags contains canary"
    only_passing = true
  }
}
failover = {
  "*" = {
    service_subset = "not-canary"
  }
}
