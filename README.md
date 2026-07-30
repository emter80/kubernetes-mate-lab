# Kubernetes Mate Lab

## Overview

A hands-on Kubernetes platform engineering project demonstrating the design, automation, and lifecycle management of a cloud-native environment using Infrastructure as Code, Kubernetes, and GitOps principles.

The project implements an end-to-end lab workflow covering infrastructure provisioning, Kubernetes cluster deployment, platform bootstrap, and automated application delivery on Linux
virtual machines running on a Windows 11 host.

The main objective is to demonstrate real-world DevOps and Platform Engineering practices by building a repeatable and declarative Kubernetes platform environment.

The project focuses on:

- Infrastructure as Code (IaC).
- Automated Kubernetes cluster lifecycle management.
- Separation of infrastructure, platform services, and application workloads.
- GitOps-based application delivery.
- Declarative configuration management.
- Automated networking and certificate management.
- Repeatable environment creation and recovery.

The implemented architecture follows patterns commonly used in modern cloud-native environments, where infrastructure, platform capabilities, and application delivery are managed as independent layers.

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

### Multipass + Terraform + K3s

Provides automated provisioning of multi-node Kubernetes environments using
Canonical Multipass virtual machines and Terraform Infrastructure as Code.

- 3-node cluster topology (1 control plane + 2 workers)
- Ubuntu Linux virtual machines
- Terraform-managed lifecycle
- GitOps features

### Vagrant + VirtualBox + K3s and K8s

Provides an alternative provisioning approach using Vagrant and VirtualBox.

- 3-node cluster topology (1 control plane + 2 workers)
- Debian Linux virtual machines
- Vagrant-managed lifecycle

---

## Development Environment

The development and testing environment used to run this project:

* **Host Operating System:** Microsoft Windows 11 Pro (64-bit)
* **Hardware Model:** Intel NUC (NUC10i5FNK)
* **Processor (CPU):** Intel Core i5-10210U @ 1.60GHz (x64-based, 4 cores / 8 threads)
* **Memory (RAM):** 16 GB Total Physical Memory

---

## Screenshots

<img width="1484" height="613" alt="image" src="https://github.com/user-attachments/assets/8b57570c-6089-4a37-ad4f-9c2edc7a6b40" />


