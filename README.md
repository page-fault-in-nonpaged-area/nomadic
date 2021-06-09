# Nomadic

**Nomadic** is an all-in-one [Consul](https://www.consul.io/)+[Nomad](https://www.nomadproject.io/) cluster builder. Nomadic produces minimal clusters ideal for testing and experiments with Nomad as a low end, low maintenance kubernetes [alternative](https://www.datocms-assets.com/2885/1605656157-hashiconfdigitaloctnomadmr-copy-001.jpeg?fit=max&fm=webp&q=80&w=1500). 

At this time Nomadic is not 100% compliant with the reference architectures for [Consul](https://learn.hashicorp.com/tutorials/consul/reference-architecture) or [Nomad](https://learn.hashicorp.com/tutorials/nomad/production-reference-architecture-vm-with-consul). High-availability is not available. Not suitable for production. Use with caution. 

**DISCLAIMER**: Please read [LICENSE](LICENSE). Nomadic and its authors are NOT responsible for damages or data losses of any kind as a result of modifying or using this tool.

## Prerequisites:

What you need: 

### Local:

One (1) Mac or Linux box with:
- [nomad](https://www.nomadproject.io/downloads)
- ssh+scp
- wget
- yq

### Cluster:
- At least 5 machines, virtual or physical:
    - Has publicly IP
    - Has internal IP (dependent on your cloud provider)
    - All 5+ reachable with one another
    - Root login permitted
- `.ssh/id_rsa.pub` of local machine on the 5+ machines.

## How to use:

1. Fill in **`config.yml`** (config.example.yml provided)
2. Run **`install.sh`**
3. Run **`ui.sh`** (preconfigured [hashi-ui](https://github.com/jippi/hashi-ui) command) to see your Nomad cluster in action!

## How it works:
    
Events happen in this approximate order:

- Bootstrapper:
    1. Reset machine to base image (hetzner example included)
    2. Install common tools.
- Build consul cluster
    1. Install specific tools.
    2. Approximately follow the [deployment guide](https://learn.hashicorp.com/tutorials/consul/deployment-guide).
    3. Transfer certs, keys, outputs to local.
- Build Nomad cluster
    1. Install specific tools.
    2. Approximately follow the [deployment guide](https://learn.hashicorp.com/tutorials/nomad/production-deployment-guide-vm-with-consul).
    3. Transfer certs, keys, outputs to local.
    4. Enable [Consul Connect](https://www.consul.io/docs/connect). 
    5. Install and configure [weavenet](https://www.weave.works/oss/net/).  


**NOTE**: The `output` folder contains certs and keys with read/write access to your cluster. 

## Q&A's:

### Why Weave?
Weave makes it flexible to run apps that require fixed and/or independent IPs per docker container. For example, [typesense](https://typesense.org/docs/0.20.0/guide/high-availability.html) in high availability. 

### Why not terraform?

Insufficient time and resources to make compatible with minor differences across different cloud providers (you can help me change that!). Terraform can provision nomadic with virtual or physical machines. When ready, template your terraform outputs into `config.yml` and run `install.sh`. 

----
Made with ❤️ in Toronto, Canada. 

If you like what you see, feel free to tip me a few Dogecoins 🐶🚀 !

![Dogecoin](assets/doge.png "Doge")

`DAygAquUdp6KxQ2bzzudto4TrXzXLqtjbF`
