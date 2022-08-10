# vSphere kURL Node

Easily create a Kubernetes node on vSphere using [kURL](https://kurl.sh)
and [Terraform](https://terraform.io)

## Goals and Audience

I created this project as a simple way to spin up a single-node
cluster on my home lab so that I could play with [KOTS](https://kots.io).
As I worked with it, I realized I could use to create multi-node
clusters or to install KOTS software using an embedded clusters.

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
* Python (for secrets management, see below)
* GPG (also fro secrets management)

## Customizing for Your Environment

To use this repostiory in your enviorment, you'll need to create
a file named `params.yaml` in the `secrets` directory. The content
of the file is documented in the file 
[`secrets/REDACTED-params.yaml`](secrets/REDACTED-params.yaml). 
Copy the redacted version to `params.yaml` and edit as apporpriate 
to connect to your cluster, specify the size of your node, etc.

## Creating a Node

The cluster is created using [Terraform](https://terraform.io), but
there's `Makefile` to make basic operations easier. Creating a
cluster with the latest versions from kURL is as simple as

```shell
$ make node
```

The output at the end will show the IP address for your node so
that you can connect to it.

By default, the node is created as a single node cluster with
the latest kURL installer. To use a custom kURL installer, 
including a KOTS install with an embedded cluster, set the 
variable `kurl_script`, for example, to use the latest k3s:

```shell
$ make node kurl_script="curl https://kurl.sh/k3s | sudo bash"
```

## Destroying the Cluster

When you're done with your cluster, you can easily destroy it 
with 

```shell
$ make destroy
```

## Protecting Secrets

There are some secrts in the `params.yaml` file, and I don't like
losing track of them so I put them in my repo. I've got a little 
helper script that I use for secrets management, and it's in the
`bin` directory. 

The script is written in Python and uses a couple of libraries
to make it a bit more ergonomic. If you want to manage your secrets
in the repositroy as well, you'll need to fork this repo and make
sure you have a GPG key. You can run `pip install -r requirement.txt`
to make sure the script dependencies are in place.

Once the script is in place, use

```shell
$ make encrypt
```

to encrypt the `params.yaml` file, and 

```shell
$ make decrypt
```

to decrypt it.
