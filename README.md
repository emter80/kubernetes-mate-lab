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
- Argo CD identity and access management integration.
- Automated networking and certificate management.
- Repeatable environment creation and recovery.

The implemented architecture follows patterns commonly used in modern cloud-native environments, where infrastructure, platform capabilities, security components and application delivery are managed as independent layers.

---
## Platform Capabilities

Beyond cluster provisioning, this project implements a complete Kubernetes platform workflow
covering application delivery, networking, and certificate management.

Implemented capabilities:

- **GitOps-based application delivery** using ArgoCD and ApplicationSets.
- **GitHub OAuth2** authentication integration for Argo CD using Dex as an identity broker.
- **Argo CD Role-Based Access Control (RBAC)** authorization based on GitHub identities.
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
- GitHub OAuth2 authentication integration for Argo CD using Dex as an identity broker.
- Argo CD Role-Based Access Control (RBAC) authorization based on GitHub identities.

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

**ArgoCD > Applications**

<img width="1074" height="614" alt="image" src="https://github.com/user-attachments/assets/69294493-735c-4dc0-ae23-0e41bdead593" />

<img width="1716" height="830" alt="image" src="https://github.com/user-attachments/assets/d9432201-3fe9-42c5-a4d5-08cc5d3724d6" />

<img width="1728" height="650" alt="image" src="https://github.com/user-attachments/assets/2d854861-acf7-4e0d-8d46-964a91bbb1dc" />

---

**ArgoCD > SSO**

Github setup
<img width="1431" height="360" alt="image" src="https://github.com/user-attachments/assets/16c8545c-ebad-4598-9bec-586030e0d81d" />
<img width="1349" height="986" alt="image" src="https://github.com/user-attachments/assets/f3970fc5-cfa6-4523-b66b-e6de643221ab" />

SSO login to ArgoCD
<img width="1598" height="343" alt="image" src="https://github.com/user-attachments/assets/7ed92d00-56a4-455b-a765-d29ab7901a7b" />

SSODeployment logs
<img width="1894" height="197" alt="image" src="https://github.com/user-attachments/assets/aa308fe9-4ab4-4a47-acb4-c6a6875a06fc" />

---

**Headlamp > Map**
<img width="1759" height="975" alt="image" src="https://github.com/user-attachments/assets/ef5853a7-28cb-44f1-8b0a-a30d89284d1f" />



