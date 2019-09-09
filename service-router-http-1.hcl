kind = "service-router"
name = "http-1"
routes = [
  {
    match {
      http {
        header = [
          {
            name = ":authority"
            prefix = "backend-service-1."
          }
        ]
      }
    }

    destination {
      service = "backend-service-1"
    }
  },
  {
    match {
      http {
        header = [
          {
            name = ":authority"
            prefix = "backend-service-2."
          }
        ]
      }
    }

    destination {
      service = "backend-service-2"
    }
  },
]
