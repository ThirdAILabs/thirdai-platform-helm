# Playbooks Folder Overview


## Descriptions

1. **`files/`**
   - This folder contains files required for the deployment and configuration of various components within the ThirdAI platform.
   - **`nomad/`**: Houses Nomad-related job specifications, node configurations, and scripts for managing Nomad.
     - **`nomad_jobs/`**: Contains templates for different Nomad jobs (e.g., model bazaar, autoscaler, Redis, Traefik).
     - **`nomad_node_configs/`**: Holds configurations for Nomad agents and related policies.
     - **`nomad_scripts/`**: Includes scripts for starting and managing Nomad agents.
   - **`telemetry_dashboards/`**: Contains JSON files used for telemetry dashboards related to Nomad allocations, clients, and servers.

2. **`roles/`**
   - Each role corresponds to a specific function or service within the ThirdAI platform, encapsulating tasks, handlers, and variables for easier management and reusability.
   - **`certs/`**: Responsible for generating and configuring certificates for secure communication.
   - **`docker_registry/`**: Manages the setup and configuration of a Docker registry.
   - **`jobs/`**: Contains tasks related to managing and submitting jobs to the Nomad scheduler.
   - **`license/`**: Handles licensing-related tasks, such as copying license files and setting permissions.
   - **`models/`**: Responsible for tasks related to model management, including uploading models.
   - **`nfs/`**: Configures and manages NFS (Network File System) clients and servers.
   - **`nomad/`**: Contains tasks for installing and managing Nomad services.
   - **`postgresql/`**: Manages the setup and configuration of PostgreSQL databases.
   - **`validation/`**: Ensures configurations are validated before deployment.

3. **`test_deploy.yml`**
   - The main playbook that orchestrates the deployment of the ThirdAI Enterprise platform. It dynamically sets up inventory and executes roles in a specified order.

## Execution Order

The execution of the `test_deploy.yml` playbook follows a structured process:

1. **Deploy ThirdAI Enterprise**
   - This initial section targets the localhost, gathering necessary configuration variables and setting up the dynamic inventory for remote hosts.

   - **Tasks executed:**
     - Load variables from an external configuration file.
     - Validate the configuration file using `validate_config.yml`.
     - Set the `model_folder` variable.
     - Dynamically add hosts based on their properties (connection type, roles, IPs).
     - The playbook loops through the defined `nodes` to establish appropriate host settings.

2. **Execute Roles on Remote Hosts**
   - This section targets all hosts defined in the dynamic inventory, gathering facts and executing a series of pre-tasks before running the defined roles.

   - **Pre-tasks executed:**
     - Load variables from the configuration file.
     - Optionally override the `thirdai_platform_version` based on the presence of Docker images.
     - Set up variables for different roles (`shared_file_system`, `critical_services`, `sql_server`, `nfs_clients`, `sql_clients`).
     - Save the private IPs of all machines in the cluster for future reference.
     - Debugging output to ensure all variables are correctly set.

3. **Roles Execution**
   - The roles are executed in the following order:
     - **validation**: The **validation** folder contains tasks to ensure system readiness before deployment. It checks SSH and sudo access, verifies internet connectivity, assesses system resources, installs netcat if missing, and tests port exposure on cluster nodes to confirm the environment is properly configured.
     - **nfs**: The **nfs** folder handles the setup and management of Network File System (NFS) for the ThirdAI platform. It includes tasks for writing and verifying node status, installing NFS clients and servers, configuring shared directories, setting access control lists (ACLs), and ensuring proper permissions and persistency for shared mounts.
     - **license**: The **license** folder manages the copying and configuration of license files for the ThirdAI platform. It includes tasks for copying both airgapped and standard license files to the appropriate shared directory, verifying successful copies, and setting the correct permissions. In case of failures, it performs rollbacks to remove any copied files or reset permissions.
     - **models**: The **models** folder manages the synchronization of generative model files within the ThirdAI platform. It includes tasks to ensure the necessary directories exist, verify the presence of the model folder, and synchronize files to the designated shared directory. If synchronization fails, it performs a rollback to remove any synchronized folders.
     - **nomad**: The **Nomad** folder manages the installation and configuration of HashiCorp's Nomad service. It includes tasks for installing Nomad on various Linux distributions, setting up Docker if needed, managing Nomad services, and ensuring the appropriate scripts and configurations are in place for both server and client nodes.
     - **postgresql**: The **PostgreSQL** folder manages the setup and configuration of a PostgreSQL server using Docker. It includes tasks to create necessary initialization scripts, install Docker images, manage the PostgreSQL container, set up users and directories, and update the SQL URI in Nomad for service integration.
     - **certs**: The **certs** folder manages SSL certificate generation and configuration for the ThirdAI platform. It includes tasks to install OpenSSL, create directories for certificates, generate SSL certificates with specific configurations, and set up a `certificates.toml` file for integration. Rollback procedures are in place for handling errors.
     - **docker_registry**: The **docker_registry** folder is responsible for setting up and configuring a local Docker registry within the ThirdAI platform. It includes tasks to:
        1. **Configure Docker**: Set up Docker to allow insecure registries and restart the Docker service.
        2. **Log in to the Registry**: Authenticate to the Docker registry using provided credentials.
        3. **Setup the Registry**: Install necessary packages, create required directories, and generate an authentication file.
        4. **Load and Push Images**: Load Docker images from local tar files, tag them, and push them to the local registry.
        5. **Run the Docker Registry**: Start the Docker registry container with appropriate authentication and storage configurations.

     - **jobs**: The **jobs** folder manages the submission and handling of Nomad jobs within the ThirdAI platform. Key tasks include:
        1. **Retrieve and Set ACL Token**: Obtain the ACL token necessary for authenticating with the Nomad server.
        2. **Submit Nomad Jobs**: 
        - Slurp necessary HCL files from the server.
        - Parse these files into JSON format for Nomad.
        - Submit the parsed jobs to the Nomad server.
        - Clean up temporary files afterward.
        3. **Setup Variables**: Establish common variables needed for job execution based on the environment.

## Adding New Roles
To add a new role:

1. Create a folder under 'roles/' with necessary tasks.
2. Include the role in test_deploy.yml in the desired execution order.

## Passing Variables Across Nodes, Roles, and Tasks

In the playbooks, variables are passed across nodes, roles, and tasks using Ansible's mechanisms like `set_fact`, inventory variables, `vars`, `group_vars`, and `host_vars`. Variables can be defined globally in playbooks or at the host level and are accessible across tasks. Within roles, variables are often specified in the `vars/` directory, allowing for role-specific configurations that are automatically loaded when the role is applied. Additionally, `set_fact` can dynamically define variables based on conditions during playbook execution. Using `include_vars` allows for external files to define variables, making them available across multiple tasks. 

For more detailed guidance on variable scoping and management, refer to the [Ansible Playbook Variables Documentation](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#scoping-variables).

## Using Vault to store key-value secrets
An example for how to create a key-value secret is as follows:
```
curl \
    --header "X-Vault-Token: ..." \
    --request POST \
    --data @payload.json \
    http://<VAULT_IP>:8200/v1/secrets/data/my-secret
```
where the payload looks like
```
{
  "data": {
    "foo": "bar",
    "zip": "zap"
  }
}
```

An example for retrieving a key-value secret is as follows:

```
curl \
    --header "X-Vault-Token: ..." \
    http://<VAULT_IP>:8200/v1/secrets/data/my-secret
```

