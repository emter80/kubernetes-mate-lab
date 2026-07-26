# Automated Kubernetes Cluster Deployment with Vagrant and VitrualBox on Debian

This project provides automated setup configurations for deploying a Kubernetes cluster on **Debian (Linux)** using **Vagrant** and **VirtualBox**, running on a **Windows 11** host. 

The repository includes deployment scripts and documentation for two distinct Kubernetes variants:
1. **K3s** – A lightweight, fully compliant, and resource-efficient distribution tailored for development and testing environments.
2. **K8s (Standard)** – A traditional Kubernetes setup for closer production-like simulations.


## My Lab Setup / Hardware Environment

The development and testing environment used to run this project:

* **Host Operating System:** Microsoft Windows 11 Pro (64-bit)
* **Hardware Model:** Intel NUC (NUC10i5FNK)
* **Processor (CPU):** Intel Core i5-10210U @ 1.60GHz (x64-based, 4 cores / 8 threads)
* **Memory (RAM):** 16 GB Total Physical Memory
* **Virtualization & Orchestration:** Oracle VirtualBox & Vagrant (with `amd64` architecture enforcement for guest nodes)


## Prerequisites

Before running this project, ensure you have the following software installed on your host machine:

* **Vagrant:** version 2.4.9 (or newer)
* **Oracle VirtualBox:** version 7.2.14 (or newer)
