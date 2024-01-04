#!/bin/bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# perma lock contract
perma_lock_tkn_script_path="../../contracts/perma_lock_tkn_contract.plutus"
perma_lock_tkn_script_address=$(${cli} address build --payment-script-file ${perma_lock_tkn_script_path} --testnet-magic ${testnet_magic})

# collat, buyer, reference
user_path="user-wallet"
user_address=$(cat ../wallets/${user_path}/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/${user_path}/payment.vkey)

# calc the min ada required for the worst case value and datum
min_utxo_value=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/datum.json \
    --tx-out="${perma_lock_tkn_script_address} + 5000000" | tr -dc '0-9')

perma_lock_tkn_script_address_out="${perma_lock_tkn_script_address} + ${min_utxo_value}"
echo "Script OUTPUT: "${perma_lock_tkn_script_address_out}
#
# exit
#
echo -e "\033[0;36m Gathering Buyer UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${user_address} \
    --out-file ../tmp/user_utxo.json
TXNS=$(jq length ../tmp/user_utxo.json)

if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${user_address} \033[0m \n";
   exit;
fi

alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/user_utxo.json)
user_tx_in=${TXIN::-8}

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${user_address} \
    --tx-in ${user_tx_in} \
    --tx-out="${perma_lock_tkn_script_address_out}" \
    --tx-out-inline-datum-file ../data/datum.json  \
    --testnet-magic ${testnet_magic})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/${user_path}/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    --testnet-magic ${testnet_magic}
#    
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    --testnet-magic ${testnet_magic} \
    --tx-file ../tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx
