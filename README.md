# Automated Kubernetes Cluster Deployment on Linux

This project provides automated Infrastructure as Code configurations for provisioning
Kubernetes clusters and deploying a GitOps-based cloud-native platform environment on Linux
virtual machines running on a Windows 11 host.

---

## Platform Capabilities

Beyond cluster provisioning, this project implements a complete Kubernetes platform workflow
covering application delivery, networking, and certificate management.

Implemented capabilities:

- **GitOps-based application delivery** using ArgoCD and ApplicationSets.
- **Helm-based application lifecycle management** with declarative configuration.
- **Multi-source ArgoCD Applications** separating Helm charts and environment configuration.
- **Kubernetes ingress management** using Traefik for application exposure.
- **Automated TLS certificate management** using cert-manager.
- **Internal Certificate Authority (CA)** for issuing and managing cluster certificates.
- **Declarative Kubernetes application deployment** through Git-based workflows.
- **Infrastructure as Code (IaC)** approach for repeatable cluster creation and configuration.
- **Cluster lifecycle automation** including provisioning, bootstrap, and application deployment.

---

## Repository Structure

The repository contains two independent infrastructure provisioning approaches:

### Multipass + Terraform

Provides automated provisioning of multi-node Kubernetes environments using
Canonical Multipass virtual machines and Terraform Infrastructure as Code.

- 3-node cluster topology (1 control plane + 2 workers)
- Ubuntu Linux virtual machines
- Terraform-managed lifecycle

### Vagrant + VirtualBox

Provides an alternative provisioning approach using Vagrant and VirtualBox.

- 3-node cluster topology (1 control plane + 2 workers)
- Debian Linux virtual machines
- Vagrant-managed lifecycle

---

## My Lab Setup / Hardware Environment

The development and testing environment used to run this project:

* **Host Operating System:** Microsoft Windows 11 Pro (64-bit)
* **Hardware Model:** Intel NUC (NUC10i5FNK)
* **Processor (CPU):** Intel Core i5-10210U @ 1.60GHz (x64-based, 4 cores / 8 threads)
* **Memory (RAM):** 16 GB Total Physical Memory
