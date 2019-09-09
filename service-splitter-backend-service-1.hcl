kind = "service-splitter"
name = "backend-service-1"
splits = [
  {
    weight         = 90
    service_subset = "not-canary"
  },
  {
    weight         = 10
    service_subset = "canary"
  },
]
