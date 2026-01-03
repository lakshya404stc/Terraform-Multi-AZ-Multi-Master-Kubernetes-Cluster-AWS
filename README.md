# KubeLaunch

**KubeLaunch** is an "awesome" end-to-end automation suite designed to deploy a production-ready, self-managed Kubernetes cluster on AWS. It handles the heavy lifting of networking, high-availability compute placement, and fully automated cluster bootstrapping with multi-node support.

---

## 🌟 Why is this Awesome?

Most automated scripts stop at a single master. **KubeLaunch** goes further by implementing a **Multi-Master High Availability (HA)** control plane including cost-effective for large clusters. It intelligently distributes your control plane nodes and workers across multiple Availability Zones (AZs) using a round-robin algorithm, ensuring that your cluster remains operational even if some AWS availability-zones goes offline.

---

**Need help?** Check out the [detailed tutorial](https://medium.com/@lakshyag404stc/simplest-way-to-deploy-a-private-kubernetes-cluster-on-aws-ec2-with-automation-74e229cbf3ee).

---

## 🏗 Modular Architecture



### 📡 A) Networking Module
The foundation of your infrastructure. It builds a secure, scalable network environment.
* **VPC & Gateway:** Provisions a custom VPC with an Internet Gateway (IGW).
* **Intelligent Subnetting:** * Dynamically creates one public and one private subnet for every AZ in the region.
    * **Customizable:** You can provide a custom list of CIDRs for both public and private tiers.
* **Secure Routing:** Deploys NAT Gateways and manages Route Tables so private nodes can pull updates safely without being exposed to the public internet.

### 💻 B) Compute Module
The engine that provisions your virtual hardware with high-availability logic.
* **Bastion Host:** Deployed in a public subnet; your secure "jump box" for cluster management.
* **Round-Robin Placement:** This logic ensures nodes are distributed evenly across AZs.
    * *Logic Example:* If you request 2 Masters and 3 Workers:
        * **Master 1** ➔ Private Subnet AZ-A
        * **Master 2** ➔ Private Subnet AZ-B
        * **Worker 1** ➔ Private Subnet AZ-C
        * **Worker 2** ➔ Private Subnet AZ-A (and so on...)

### ☸️ C) K8s-Cluster Module (The "Magic" Layer)
The configuration layer that transforms EC2s into a living, breathing cluster.
* **Security Group Orchestration:** Automatically provisions and attaches SG rules for all nodes and the Bastion host, opening only the necessary ports for K8s communication (6443, 2379-2380, etc.).
* **Full Stack Installation:** Automated install of container runtimes (Docker/Containerd), `kubeadm`, `kubelet`, and `kubectl`.
* **Multi-Master Bootstrapping:** * Initializes **Master Node 1** as the primary control plane.
    * **Automated Join:** Securely joins additional Master nodes to the control plane to achieve High Availability.
    * **Worker Integration:** Automatically joins all Worker nodes to the cluster.
    * **Result:** A fully formed, multi-master cluster ready for production workloads immediately.

---

## 🏗 Project Structure

The project follows a clean, professional Terraform directory structure to separate environment-specific configurations from the core logic modules:

```text
.
├── .github/              # CI/CD Workflows
├── envs/                 # Environment-specific configs
│   ├── dev/              # Development environment (main.tf, variables.tf, etc.)
│   └── prod/             # Production environment
└── modules/              # Core Logic (The "Engine")
    ├── network/          # VPC, Subnets, NAT Gateways, Route Tables
    ├── compute/          # EC2 Provisioning & Round-Robin Logic
    └── k8s-cluster/      # SG rules, HA Bootstrapping, and Join logic

```
---

## 🛠 Features at a Glance

| Feature | Description |
| :--- | :--- |
| HA Design | Multi-Master and Multi-AZ by default with round-robin placement. |
| Security | Private subnets for all nodes; Bastion-only SSH access. |
| Flexibility | Custom CIDR support for networking experts. |
| Automation | Full K8s bootstrap—no manual kubeadm join required. |

---
*Built to make Kubernetes infrastructure deployment truly awesome.*
