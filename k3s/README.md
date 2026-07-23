# Installation

1. **Ensure prerequisites are installed**
   Vagrant and VirtualBox

2. **Clone the repository**
   ```bash
   git clone https://github.com/emter80/kubernetes-vagrant-lab.git
   ```

3. **Navigate to the directory**
   ```bash
   cd ./kubernetes-vagrant-lab/k3s
   ```

4. **Run the installation**
   ```bash
   vagrant up
   ```

5. Check existing machines
   ```bash
   vagrant status
   ```

6. Log in to the control plane node and check status
   ```bash
   vagrant ssh k3s-control
   kubectl get nodes -o wide
   kubectl get pod -A -o wide
   ```
