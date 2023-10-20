#!/bin/bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ./data/path_to_socket.sh)
cli=$(cat ./data/path_to_cli.sh)
testnet_magic=$(cat ./data/testnet.magic)

if [[ $# -eq 0 ]] ; then
    echo -e "\n \033[0;31m Please Supply A Token Amount \033[0m \n";
    exit
fi

if [[ ${1} -eq 0 ]] ; then
    echo -e "\n \033[0;31m Token Amount Must Be Greater Than Zero \033[0m \n";
    exit
fi

token_amt=${1}

# update the add amount but account for any size number up to 2^63 -1
python -c "import json; data=json.load(open('./data/add-token-redeemer.json', 'r')); data['fields'][0]['int'] = $token_amt; json.dump(data, open('./data/add-token-redeemer.json', 'w'), indent=2)"

# perma lock contract
script_path="../contracts/perma_lock_contract.plutus"
script_address=$(${cli} address build --payment-script-file ${script_path} --testnet-magic ${testnet_magic})

# user wallet
user_path="user-wallet"
user_address=$(cat ./wallets/${user_path}/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ./wallets/${user_path}/payment.vkey)

# collat wallet
collat_address=$(cat ./wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ./wallets/collat-wallet/payment.vkey)

echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${script_address} \
    --testnet-magic ${testnet_magic} \
    --out-file ./tmp/script_utxo.json

# transaction variables
TXNS=$(jq length ./tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ./tmp/script_utxo.json)
script_tx_in=${TXIN::-8}


locking_pid=$(jq -r '.lockingPid' ../start_info.json)
locking_tkn=$(jq -r '.lockingTkn' ../start_info.json)
# this should work for the min lovelace
script_lovelace=$(jq '[.[] | .value.lovelace] | add' ./tmp/script_utxo.json)
# get the current token amount but account for numbers below 2^63 -1
script_token=$(python -c "import json; data=json.load(open('./tmp/script_utxo.json')); print(next((item['value']['${locking_pid}']['${locking_tkn}'] for item in data.values() if '${locking_pid}' in item['value'] and '${locking_tkn}' in item['value']['${locking_pid}']), 0))")
echo $script_token

# should handle large numbers just fine
token_amt=$(echo "${script_token} + ${1}" | bc)

script_address_out="${script_address} + ${script_lovelace} + ${token_amt} ${locking_pid}.${locking_tkn}"
echo "Script OUTPUT: "${script_address_out}

echo -e "\033[0;36m Gathering User UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${user_address} \
    --out-file ./tmp/user_utxo.json

TXNS=$(jq length ./tmp/user_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${user_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ./tmp/user_utxo.json)
user_tx_in=${TXIN::-8}

echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${collat_address} \
    --out-file ./tmp/collat_utxo.json

TXNS=$(jq length ./tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_utxo=$(jq -r 'keys[0]' ./tmp/collat_utxo.json)

# get script reference
script_ref_utxo=$(${cli} transaction txid --tx-file ./tmp/perma-lock-reference-utxo.signed)

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ./tmp/tx.draft \
    --change-address ${user_address} \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${user_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ./data/add-token-redeemer.json \
    --tx-out="${script_address_out}" \
    --tx-out-inline-datum-file ./data/datum.json  \
    --required-signer-hash ${collat_pkh} \
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
    --signing-key-file ./wallets/${user_path}/payment.skey \
    --signing-key-file ./wallets/collat-wallet/payment.skey \
    --tx-body-file ./tmp/tx.draft \
    --out-file ./tmp/tx.signed \
    --testnet-magic ${testnet_magic}
#    
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    --testnet-magic ${testnet_magic} \
    --tx-file ./tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ./tmp/tx.signed)
echo "Tx Hash:" $tx