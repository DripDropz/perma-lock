#!/bin/bash
set -e

export CARDANO_NODE_SOCKET_PATH=$(cat ../data/path_to_socket.sh)
cli=$(cat ../data/path_to_cli.sh)
testnet_magic=$(cat ../data/testnet.magic)


wait_for_block_change() {
    # Initial fetch of the current block
    last_block=$(${cli} query tip --testnet-magic ${testnet_magic} | jq -r '.block')

    # Loop indefinitely until a block change is detected
    while true
    do
        # Fetch the current block
        cur_block=$(${cli} query tip --testnet-magic ${testnet_magic} | jq -r '.block')

        # Check if the current block has changed
        if [ "$cur_block" != "$last_block" ]; then

            tx_in_mempool=$(${cli} query tx-mempool info --testnet-magic ${testnet_magic} | jq -r '.numberOfTxs')
            # Check if the current block has changed
            if [ "$tx_in_mempool" == 0 ]; then
                # Block has changed, exit the loop
                echo "Continue."
                break
            fi
        fi

        # Sleep briefly to avoid hammering the command
        sleep 1
    done
}

wait_for_block_change

for i in {1..36}
do
    # Call the other Bash script
    pushd ../worst_case_minting/ > /dev/null
    ./mintToken.sh
    # Return to the previous directory
    popd > /dev/null

    wait_for_block_change
done


# user wallet
user_path="user-wallet"
user_address=$(cat ../wallets/${user_path}/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/${user_path}/payment.vkey)

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

# get the user tokens and add all of them to the nft lock
python ../py/tokens.py

user_token_string=$(cat ../data/token_string.txt)

echo $user_token_string

# stake key
stake_key=$(jq -r '.stakeKey' ../../start_info.json)

# perma lock contract
perma_lock_nft_script_path="../../contracts/perma_lock_nft_contract.plutus"
perma_lock_nft_script_address=$(${cli} address build --payment-script-file ${perma_lock_nft_script_path} --stake-address ${stake_key} --testnet-magic ${testnet_magic})

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

script_token_string=$(python -c "
import json

with open('../tmp/script_utxo.json', 'r') as file:
    data = json.load(file)

result = []
for item in data.values():
    for pid, tokens in item['value'].items():
        if pid != 'lovelace':
            for tkn, amt in tokens.items():
                result.append(f'{amt} {pid}.{tkn}')

print(' + '.join(result))
")

# should handle large numbers just fine

if [ -z "$script_token_string" ]; then
    tokens="$user_token_string"
    # You can also perform other actions here if needed
    # calc the min ada required for the worst case value and datum
    min_utxo_value=$(${cli} transaction calculate-min-required-utxo \
        --babbage-era \
        --protocol-params-file ../tmp/protocol.json \
        --tx-out-inline-datum-file ../data/datum.json \
        --tx-out="${perma_lock_nft_script_address} + 5000000 + ${tokens}" | tr -dc '0-9')

    perma_lock_nft_script_address_out="${perma_lock_nft_script_address} + ${min_utxo_value} + ${tokens}"
else
    tokens="${script_token_string} + ${user_token_string}"
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

# exit

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