#!/usr/bin/env bash
set -e

tkn() {
    python3 -c "import secrets; print(''.join([secrets.choice('0123456789abcdef') for _ in range(56)]))"
}

export CARDANO_NODE_SOCKET_PATH=$(cat ../../data/path_to_socket.sh)
cli=$(cat ../../data/path_to_cli.sh)
network=$(cat ../../data/network.sh)

# minting policy
mint_path1="./policy1.script"
mint_path2="./policy2.script"

batcher_address=$(cat ../../wallets/batcher-wallet/payment.addr)
batcher_pkh=$(${cli} conway address key-hash --payment-verification-key-file ../../wallets/batcher-wallet/payment.vkey)

policy_id1=$(${cli} conway transaction policyid --script-file ${mint_path1})
policy_id2=$(${cli} conway transaction policyid --script-file ${mint_path2})

# assets
mint_asset1="
1 ${policy_id1}.44618a67$(tkn) + 
1 ${policy_id1}.45b555bd$(tkn) + 
1 ${policy_id1}.4cae2fd2$(tkn) + 
1 ${policy_id1}.57d8ea10$(tkn) + 
1 ${policy_id1}.5f3a83b8$(tkn) + 
1 ${policy_id1}.6aa8bd5d$(tkn) + 
1 ${policy_id1}.726aaa90$(tkn) + 
1 ${policy_id1}.8be2ee9c$(tkn) + 
1 ${policy_id1}.8c4234e8$(tkn) + 
1 ${policy_id1}.d05fd9e2$(tkn)"
mint_asset2="
1 ${policy_id2}.ecf39067$(tkn) + 
1 ${policy_id2}.0892f565$(tkn) + 
1 ${policy_id2}.0c55ccd7$(tkn) + 
1 ${policy_id2}.3d4d9807$(tkn) + 
1 ${policy_id2}.520fc569$(tkn) + 
1 ${policy_id2}.5c99b6b4$(tkn) + 
1 ${policy_id2}.63e2123b$(tkn) + 
1 ${policy_id2}.78820b6c$(tkn) + 
1 ${policy_id2}.a16af814$(tkn) + 
1 ${policy_id2}.ad997a92$(tkn) + 
1 ${policy_id2}.e7982636$(tkn)"


minted_assets=$(echo "${mint_asset1} + ${mint_asset2}" | tr -d '\n')

# mint utxo
utxo_value=$(${cli} conway transaction calculate-min-required-utxo \
    --protocol-params-file ../../tmp/protocol.json \
    --tx-out="${batcher_address} + 2000000 + ${mint_asset1} + ${mint_asset2}" | tr -dc '0-9')

batcher_address_out="${batcher_address} + ${utxo_value} + ${mint_asset1} + ${mint_asset2}"
echo "Mint OUTPUT: "${batcher_address_out}
#
# exit
#
echo -e "\033[0;36m Gathering User UTxO Information  \033[0m"
${cli} conway query utxo \
    ${network} \
    --address ${batcher_address} \
    --out-file ../../tmp/batcher_utxo.json

TXNS=$(jq length ../../tmp/batcher_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${batcher_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../../tmp/batcher_utxo.json)
batcher_tx_in=${TXIN::-8}

# slot contraints
slot=$(${cli} conway query tip ${network} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 2500))

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} conway transaction build \
    --out-file ../../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --change-address ${batcher_address} \
    --tx-in ${batcher_tx_in} \
    --tx-out="${batcher_address_out}" \
    --mint-script-file ${mint_path1} \
    --mint-script-file ${mint_path2} \
    --mint="${minted_assets}" \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} conway transaction sign \
    --signing-key-file ../../wallets/batcher-wallet/payment.skey \
    --tx-body-file ../../tmp/tx.draft \
    --out-file ../../tmp/tx.signed \
    ${network}
#    
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} conway transaction submit \
    ${network} \
    --tx-file ../../tmp/tx.signed

tx=$(${cli} conway transaction txid --tx-file ../../tmp/tx.signed)
echo "Tx Hash:" $tx