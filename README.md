# vSphere Talos Cluster

Easily create a Kubernetes cluster on vSphere using [Talos](https://talos.dev)
and [Terraform](https://terraform.io)

## Goals and Audience

I created this project as a simple way to spin up a single-node kURL
cluster on my home lab so that I could play with [KOTS](https://kots.io).
As I worked with it, I realized I could use to create multi-node
clusters. Then I learned about k0s and decided to see if I could adapt
what I was doing to building k0s clusters. After that, I was hooked
on seeing what types of clusters I could build. Now onto Talos.

The initial audience was me and my peers at Replicated, but I think
anyone working needing small clusters in a Lab environment could find
it use full.

## Requirements

### Required

* A vSphere cluster
* Your favorite editor
* A Unix-y workstation (WSL should work)
* Make
* Terraform
* Direnv
* SOPS (for secrets management)
* GPG (for SOPS)
* [`talosctl`](https://github.com/k0sproject/k0sctl#installation)

## Customizing for Your Environment

To use this repostiory in your enviorment, you'll need to create
a file named `params.yaml` in the `secrets` directory. The content
of the file is documented in the file 
[`secrets/REDACTED-params.yaml`](secrets/REDACTED-params.yaml). 
Copy the redacted version to `params.yaml` and edit as apporpriate 
to connect to your cluster, specify the size of your node, etc.

## Creating a Cluster

The cluster is created using [Terraform](https://terraform.io), but
there's `Makefile` to make basic operations easier. Creating a
cluster with the latest versions from kURL is as simple as

```shell
$ make cluster
```

The output at the end will show the IP address for your control plane node so
that you can connect to it.

By default, the node is created as a multi-node cluster with
the latest Talos installer. The cluster has as single control plane
node and 2 workers. 

## Destroying the Cluster

When you're done with your cluster, you can easily destroy it 
with 

```shell
$ make destroy
```

## Protecting Secrets

There are some secrts in the `params.yaml` file, and I don't like
losing track of them so I put them in my repo. They are managed
with [SOPS](https://github.com/mozilla/sops)

The script is written in Python and uses a couple of libraries
to make it a bit more ergonomic. If you want to manage your secrets
in the repositroy as well, you'll need to fork this repo and make
changes to the SOPS configuration in `.sops.yaml` (and put your
public key into `.sops.pub.asc`).

There are a couple of `make` targets to facilitate working with
the encrypted file.

```shell
$ make encrypt
```

to encrypt the `params.yaml` file, and 

```shell
$ make decrypt
```

to decrypt it.

You can also edit it directly with `sops ${SECRETS_DIR}/params.yaml`.
