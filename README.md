# Automated Kubernetes Cluster Deployment on Linux

This project provides automated setup configurations for deploying a Kubernetes cluster (K3s and K8s) on Linux guest (Windows 11 host).

> **K3s** – A lightweight, fully compliant, and resource-efficient distribution tailored for development and testing environments.
> 
> **K8s** – A traditional Kubernetes setup for closer production-like simulations.

---

## Repository Structure

This repository is organized into distinct directories based on the virtualization and automation tooling used:

### 1. `vagrant/`
Contains configurations for setting up both **K3s** and **K8s** clusters using **Vagrant** and **VirtualBox**. 
3 nodes (control + 2 workers) cluster lab environment installed on Debian linux and managed via Vagrantfiles.

### 2. `multipass/ #<TBD>` 
Contains configurations for setting up **K3s** and **K8s** clusters using Canonical's **Multipass** combined with **Terraform**.
3 nodes (control + 2 workers) cluster lab environment installed on Ubuntu VM linux and managed Terraform.

---

## My Lab Setup / Hardware Environment

The development and testing environment used to run this project:

* **Host Operating System:** Microsoft Windows 11 Pro (64-bit)
* **Hardware Model:** Intel NUC (NUC10i5FNK)
* **Processor (CPU):** Intel Core i5-10210U @ 1.60GHz (x64-based, 4 cores / 8 threads)
* **Memory (RAM):** 16 GB Total Physical Memory
