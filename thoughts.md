## Open CNI Plugins

These might be the cause of compatibility issues in the future. Example:

On Debian Buster, the current v0.8.1 release doesn't work out of the box
because of Buster's use of nftables. On cleanup/startup, there's an iptables
command that calls `iptables --wait`, which throws an unexpected exit code.

The underlying bad handling of this is coreos/go-iptables (which was changed
in https://github.com/coreos/go-iptables/pull/62), but that fix doesn't handle
any backwards compatibility with older versions of iptables/nftables - so it's
no good for newer releases including that version of go-iptables, where the
version of iptables/nftables isn't 1.8.1.

Picked via: https://github.com/containernetworking/plugins/issues/335#issuecomment-510112914

(On Buster, configure the host to use iptables instead of nftables for now)

## LocalServicePort Should be Configured

It looks like right now, `LocalServicePort` isn't passed to the Connect
configuration for a service, which means the port used by Connect is the port
exposed in the Consul service.

For example, a job:

```hcl
    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    service {
      name = "backend-service-1"
      port = "http"
```

Creates a Consul service with the mapped port for http/80, but Connect services
will try to use that mapped port when delivering traffic locally. The fix is to
use the port value:

```hcl
    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    service {
      name = "backend-service-1"
      port = "80"
```

The problem is, this results in the Consul service being created with 80 as the
port. This breaks the ability to access a service directly via its Consul name
(mixed environment moving to Connect, for example)

If `LocalServicePort` is configured with port 80 when registering the Consul
service, this shouldn't be a problem:

```
	// LocalServicePort is the port of the local service instance. It is optional
	// and should only be specified for "side-car" style proxies. It will default
	// to the registered port for the instance if the proxy is a "side-car"
	// (DestinationServiceID is set) but otherwise will be ignored.
```

## Splitter/Resolver Not Working Properly

Need to look into - not sure why but no backends/clusters show up in Envoy
when filtering based on tag. There's also a <nil> error in the Consul logs
worth looking into

## Intentions Only Apply on Service Start

Documented behaviour in Consul - probably because of persistent connections/
how authz plugins in Envoy work.

See also https://github.com/hashicorp/consul/issues/6454

## Exposing Admin Port for Envoy (Prometheus Metrics Scraping)

Need to look into.

## DC Based Routing

Right now we have a couple of L5D routers that allow for routing with a Consul DC
(`us-central1`) based on header (`X-BC-Datacenter`). We want to be able to leverage
something similar for international expansion.

ie:

```
Host: backend-service1.linkerd
X-BC-Datacenter: au-southeast1

GET /
```

- Route to `backend-service1` in au-southeast1.

Need to look at a service resolver/router to see if this is supported? Seems like
this might need `ServiceRouteDestination` to support DCs?

We'd want to do this without building a single `service-router` entry with all the
possible permutations.

It seems like Mesh Gateways are supposed to be the approach here, but I don't think
it's possible to select/choose a gateway based on a header. Maybe a new config
type should be added to support this?

## Capture Groups for Service Routers & Destinations

Something like this might be nice to simplify routing for `http-out`:

```hcl
kind = "service-router"
name = "http-1"
routes = [
  {
    match {
      http {
        header = [
          {
            name = ":authority"
            regex = "(?<dest_service>[^\.]+)."
          }
        ]
      }
    }

    destination {
      service = "$dest_service"
    }
  }
]
```
