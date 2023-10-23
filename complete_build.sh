#!/bin/bash
set -e

# create directories if dont exist
mkdir -p contracts
mkdir -p hashes

# remove old files
rm contracts/* || true
rm hashes/* || true

# build out the entire script
echo -e "\033[1;34m Building Contracts \033[0m"

# standard build
aiken build

# keep the traces for testing if required
# aiken build --keep-traces

# build out the entire script
echo -e "\033[1;34m Building Token Data \033[0m"

# the locking token information
locking_pid=$(jq -r '.lockingPid' start_info.json)
locking_tkn=$(jq -r '.lockingTkn' start_info.json)

# one liner for correct cbor
locking_pid_cbor=$(python3 -c "import cbor2;hex_string='${locking_pid}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")
locking_tkn_cbor=$(python3 -c "import cbor2;hex_string='${locking_tkn}';data = bytes.fromhex(hex_string);encoded = cbor2.dumps(data);print(encoded.hex())")

echo -e "\033[1;33m Convert Perma Lock Contract \033[0m"

aiken blueprint apply -o plutus.json -v perma.params "${locking_pid_cbor}"
aiken blueprint apply -o plutus.json -v perma.params "${locking_tkn_cbor}"
aiken blueprint convert -v perma.params > contracts/perma_lock_contract.plutus

# store the script hash
echo -e "\033[1;34m Building Contract Hash Data \033[0m"
cardano-cli transaction policyid --script-file contracts/perma_lock_contract.plutus > hashes/perma_lock.hash

# end of build
echo -e "\033[1;32m Building Complete! \033[0m"