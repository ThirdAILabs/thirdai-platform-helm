# Check for command-line argument
if [ "$#" -ne 8 ]; then
    echo "Usage: $0 <server_enabled> <client_enabled> <node_pool> <node_class> <curr_nomad_server_private_ip> <nomad_server_private_ips> <bootstrap_expect> <nomad_vault_token>"
    exit 1
fi

export SERVER_ENABLED=$1
export CLIENT_ENABLED=$2
export NODE_POOL=$3

if [ "$4" != "default" ]; then
    export NODE_CLASS_STRING="node_class = \"${4}\""
else
    export NODE_CLASS_STRING=""
fi

export CURR_NOMAD_SERVER_PRIVATE_IP=$5
export NOMAD_SERVER_PRIVATE_IPS=$6
export BOOTSTRAP_EXPECT=$7

export NOMAD_VAULT_TOKEN=$8

envsubst < ./nomad/nomad_node_configs/nomad_agent_config.hcl.tpl > ./nomad/nomad_node_configs/nomad_agent_config.hcl