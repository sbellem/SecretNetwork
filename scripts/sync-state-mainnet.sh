#!/bin/bash

set -ex

username=`id -un`
scrt_home=${SCRT_HOME:-${HOME}/.secretd}

exit_script() {
    echo "${username} must be stopped first before doing a state sync"
    echo -e "stop ${username} with:\n\tsudo systemctl stop ${username}"
    exit 1
}

edit_config() {
    snap_rpc="https://rpc.secret.express:443"
    rpc_servers="http://89.149.206.165:26657,http://89.149.206.165:26657"
    #rpc_servers="https://rpc.cosmos.directory:443/secretnetwork,https://rpc.secret.express:443"
    block_height=$(curl -s ${snap_rpc}/block | jq -r .result.block.header.height | awk '{print $1 - ($1 % 2000)}'); \
    trust_hash=$(curl -s "${snap_rpc}/block?height=${block_height}" | jq -r .result.block_id.hash)

    sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
	    s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"${rpc_servers}\"| ; \
	    s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1${block_height}| ; \
	    s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"${trust_hash}\"|" ${scrt_home}/config/config.toml
}

edit_config_app() {
    # set iavl-disable-fastnode = true
    sed "s/iavl-disable-fastnode = false/iavl-disable-fastnode = true/" -i ${scrt_home}/config/app.toml
    
    # snapshot interval
    sed "s/snapshot-interval = 0/snapshot-interval = 5000/" -i ${scrt_home}/config/app.toml
}

reset_tmp_dir() {
    #find /tmp/ -user ${username} | xargs rm -r
    cd /tmp
    ls -l | awk -v user=${username} '$3==user { print $9 }' | xargs rm -rf
    cd $HOME
}

reset_data() {
    rm -rf ${scrt_home}/data
    rm -rf ${scrt_home}/.compute
    secretd --home ${scrt_home} tendermint unsafe-reset-all
    mkdir -p ${scrt_home}/data/snapshots
}

systemctl --quiet is-active ${username} && exit_script ||

edit_config_app
reset_tmp_dir
reset_data
edit_config
