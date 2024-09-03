#!/usr/bin/env bash
set -e

#
export CARDANO_NODE_SOCKET_PATH=$(cat ./data/path_to_socket.sh)
cli=$(cat ./data/path_to_cli.sh)
network=$(cat ./data/network.sh)

mkdir -p ./tmp
${cli} conway query protocol-parameters ${network} --out-file ./tmp/protocol.json

# staking contract
stake_script_path="../contracts/stake_contract.plutus"

# bundle sale contract
sale_script_path="../contracts/sale_contract.plutus"
sale_script_address=$(${cli} conway address build --payment-script-file ${sale_script_path} --stake-script-file ${stake_script_path} ${network})

# queue contract
queue_script_path="../contracts/queue_contract.plutus"
queue_script_address=$(${cli} conway address build --payment-script-file ${queue_script_path} --stake-script-file ${stake_script_path} ${network})

# band lock contract
band_lock_script_path="../contracts/band_lock_contract.plutus"
band_lock_script_address=$(${cli} conway address build --payment-script-file ${band_lock_script_path} --stake-script-file ${stake_script_path} ${network})

# vault contract
vault_script_path="../contracts/vault_contract.plutus"
vault_script_address=$(${cli} conway address build --payment-script-file ${vault_script_path} --stake-script-file ${stake_script_path} ${network})

# reference contract address
ref_script_path="../contracts/reference_contract.plutus"
ref_script_address=$(${cli} conway address build --payment-script-file ${ref_script_path} ${network})

#
${cli} conway query protocol-parameters ${network} --out-file ./tmp/protocol.json
${cli} conway query tip ${network} | jq

#
echo -e "\033[1;35m\nReference Script Address: \033[0m"
echo -e "\n \033[1;32m ${ref_script_address} \033[0m \n";
${cli} conway query utxo --address ${ref_script_address} ${network}
# update the data folder with the current reference datum
${cli} conway query utxo --address ${ref_script_address} ${network} --out-file ./tmp/current_reference_utxo.json
jq -r 'to_entries[] | .value.inlineDatum' tmp/current_reference_utxo.json > data/reference/current-reference-datum.json

#
echo -e "\033[1;35m\nSale Script Address: \033[0m" 
echo -e "\n \033[1;32m ${sale_script_address} \033[0m \n";
${cli} conway query utxo --address ${sale_script_address} ${network}
${cli} conway query utxo --address ${sale_script_address} ${network} --out-file ./tmp/current_sale_utxo.json

#
echo -e "\033[1;35m\nQueue Script Address: \033[0m" 
echo -e "\n \033[1;32m ${queue_script_address} \033[0m \n";
${cli} conway query utxo --address ${queue_script_address} ${network}
${cli} conway query utxo --address ${queue_script_address} ${network} --out-file ./tmp/current_queue_utxo.json

#
echo -e "\033[1;35m\nBand Lock Up Script Address: \033[0m" 
echo -e "\n \033[1;32m ${band_lock_script_address} \033[0m \n";
${cli} conway query utxo --address ${band_lock_script_address} ${network}
${cli} conway query utxo --address ${band_lock_script_address} ${network} --out-file ./tmp/current_band_lock_utxo.json

echo -e "\033[1;35m\nVault Script Address: \033[0m"
echo -e "\n \033[1;32m ${vault_script_address} \033[0m \n";
${cli} conway query utxo --address ${vault_script_address} ${network}
${cli} conway query utxo --address ${vault_script_address} ${network} --out-file ./tmp/current_vault_utxo.json

# Loop through each -wallet folder
for wallet_folder in wallets/*-wallet; do
    # Check if payment.addr file exists in the folder
    if [ -f "${wallet_folder}/payment.addr" ]; then
        addr=$(cat ${wallet_folder}/payment.addr)
        echo
        
        echo -e "\033[1;37m --------------------------------------------------------------------------------\033[0m"
        echo -e "\033[1;34m $wallet_folder\033[0m\n\n\033[1;32m $addr\033[0m"
        

        echo -e "\033[1;33m"
        # Run the cardano-cli command with the reference address and testnet magic
        ${cli} conway query utxo --address ${addr} ${network}
        ${cli} conway query utxo --address ${addr} ${network} --out-file ./tmp/"${addr}.json"

        baseLovelace=$(jq '[.. | objects | .lovelace] | add' ./tmp/"${addr}.json")
        echo -e "\033[0m"

        echo -e "\033[1;36m"
        ada=$(echo "scale = 6;${baseLovelace} / 1000000" | bc -l)
        echo -e "TOTAL ADA:" ${ada}
        echo -e "\033[0m"
    fi
done
