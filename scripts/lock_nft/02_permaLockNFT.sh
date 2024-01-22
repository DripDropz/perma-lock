#!/bin/bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)

# Check if less than 3 arguments are supplied
if [[ $# -lt 3 ]] ; then
    echo -e "\n \033[0;31m Please Supply At Least 3 Arguments: policy_id, token_name, amount \033[0m \n";
    exit 1
fi

# Check if the third argument (amount) is not greater than zero
if ! [[ ${3} =~ ^[0-9]+$ ]] || [[ ${3} -le 0 ]] ; then
    echo -e "\n \033[0;31m Token Amount Must Be A Positive Number Greater Than Zero \033[0m \n";
    exit 1
fi


asset_pid=${1}
asset_tkn=${2}
asset_amt=${3}

echo Adding ${asset_amt} ${asset_pid}.${asset_tkn}

python -c "
import json
data=json.load(open('../data/add-nft-redeemer.json', 'r'))
data['fields'][0]['list'][0]['fields'][0]['bytes'] = '$asset_pid'
data['fields'][0]['list'][0]['fields'][1]['bytes'] = '$asset_tkn'
data['fields'][0]['list'][0]['fields'][2]['int'] = $asset_amt
json.dump(data, open('../data/add-nft-redeemer.json', 'w'), indent=2)
"

# stake key
stake_key=$(jq -r '.stakeKey' ../../start_info.json)

# perma lock contract
perma_lock_nft_script_path="../../contracts/perma_lock_nft_contract.plutus"
perma_lock_nft_script_address=$(${cli} address build --payment-script-file ${perma_lock_nft_script_path} --stake-address ${stake_key} --testnet-magic ${testnet_magic})

# user wallet
user_path="user-wallet"
user_address=$(cat ../wallets/${user_path}/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/${user_path}/payment.vkey)

# collat wallet
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

echo -e "\033[0;36m Gathering Script UTxO Information  \033[0m"
${cli} query utxo \
    --address ${perma_lock_nft_script_address} \
    --testnet-magic ${testnet_magic} \
    --out-file ../tmp/script_utxo.json

# transaction variables
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${perma_lock_nft_script_address} \033[0m \n";
   exit;
fi
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
script_tx_in=${TXIN::-8}

unique_policies=$(jq 'to_entries[] | {key: .key, value_count: (.value.value | length)} | .value_count' ../tmp/script_utxo.json)
echo There are ${unique_policies} policies on the UTxO

# this should work for the min lovelace
current_token_amt=$(python -c "
import json

with open('../tmp/script_utxo.json', 'r') as file:
    data = json.load(file)

asset_pid = '${asset_pid}'
asset_tkn = '${asset_tkn}'

script_token_value = next(
    (item['value'][asset_pid][asset_tkn] for item in data.values() 
     if asset_pid in item['value'] and asset_tkn in item['value'][asset_pid]), 
    0
)

print(script_token_value)
")

token_string=$(python -c "
import json

with open('../tmp/script_utxo.json', 'r') as file:
    data = json.load(file)

result = []
for item in data.values():
    for pid, tokens in item['value'].items():
        if pid != 'lovelace':
            for tkn, amt in tokens.items():
                if pid != '${asset_pid}' or tkn != '${asset_tkn}':
                    result.append(f'{amt} {pid}.{tkn}')

print(' + '.join(result))
")

# should handle large numbers just fine
token_amt=$(echo "${current_token_amt} + ${3}" | bc)

if [ -z "$token_string" ]; then
    tokens="${token_amt} ${asset_pid}.${asset_tkn}"
    # You can also perform other actions here if needed
    # calc the min ada required for the worst case value and datum
    min_utxo_value=$(${cli} transaction calculate-min-required-utxo \
        --babbage-era \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/datum.json \
        --tx-out="${perma_lock_nft_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')

    perma_lock_nft_script_address_out="${perma_lock_nft_script_address} + ${min_utxo_value} + ${tokens}"
else
    tokens="${token_amt} ${asset_pid}.${asset_tkn} + ${token_string}"
    # You can also perform other actions here if needed
    # calc the min ada required for the worst case value and datum
    min_utxo_value=$(${cli} transaction calculate-min-required-utxo \
        --babbage-era \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/datum.json \
        --tx-out="${perma_lock_nft_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')

    perma_lock_nft_script_address_out="${perma_lock_nft_script_address} + ${min_utxo_value} + ${tokens}"
fi

echo "Script OUTPUT: "${perma_lock_nft_script_address_out}

echo -e "\033[0;36m Gathering User UTxO Information  \033[0m"
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

echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    --testnet-magic ${testnet_magic} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json

TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_utxo=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)

# get script reference
script_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/perma-lock-nft-reference-utxo.signed)

# exit
echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --change-address ${user_address} \
    --tx-in-collateral="${collat_utxo}" \
    --tx-in ${user_tx_in} \
    --tx-in ${script_tx_in} \
    --spending-tx-in-reference="${script_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/add-nft-redeemer.json \
    --tx-out="${perma_lock_nft_script_address_out}" \
    --tx-out-inline-datum-file ../data/datum.json  \
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
    --signing-key-file ../wallets/${user_path}/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
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