job "multitool" {

  datacenters = ["FSN-1"]
  type = "service"

  group "multitool" {
    count = 1

    network {
      mode="cni/weave"
    }

    task "multitool-1" {

      service {
        name = "multitool-1"
        tags = ["multitool"]
      }

      driver = "docker"
      config {
        image = "praqma/network-multitool"
        command = "sh"
        network_mode = "weave"
        args = ["-c", "while true; do echo 'hello'; sleep 5; done"]
      }

      resources {
        cpu    = 250
        memory = 512
      }
    }
  }
}
