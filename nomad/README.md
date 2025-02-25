# ThirdAI Platform Deployment with Ansible

This project automates the deployment of ThirdAI Platform using Ansible. The playbook handles the setup and configuration of various components such as web ingress, SQL server, and NFS shared directories across multiple nodes.

## Prerequisites

- Ansible installed on the control machine.
- SSH access to all target nodes.
- A configuration file (`config.yml`) containing necessary variables and node definitions.

## Deployment


Follow this for installing ansible: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip

To deploy ThirdAI Platform, execute the following command:
```bash
GENERATIVE_MODEL_FOLDER="" # Keep this as empty string if we dont want to use qwen model. 

GENERATIVE_MODEL_FOLDER=$(realpath "$GENERATIVE_MODEL_FOLDER")

ansible-playbook playbooks/test_deploy.yml --extra-vars "config_path=/path/to/your/config.yml generative_model_folder=$GENERATIVE_MODEL_FOLDER"

# To cleanup a deployment, execute the following command

ansible-playbook playbooks/test_cleanup.yml --extra-vars "config_path=/path/to/your/config.yml generative_model_folder=$GENERATIVE_MODEL_FOLDER"

```
