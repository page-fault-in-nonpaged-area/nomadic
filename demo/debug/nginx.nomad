job "service-web" {

  datacenters = ["FSN-1"]
  type = "service"

  group "service-web" {
    count = 1

    network {
      mode="cni/weave"
    }

    task "service-web" {

      driver = "docker"

      config {
        image = "nginx"
        network_mode = "weave"
      }

      service {
        name = "service-web"
        address_mode = "driver"
        port = "80"
      }

      resources {
        cpu    = 300 # MHz
        memory = 128 # MB
      }
    }
  }
}
