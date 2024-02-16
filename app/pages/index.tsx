import Head from "next/head";
import {
  Transaction,
  MeshTxBuilder,
  KoiosProvider,
  resolveDataHash,
} from "@meshsdk/core";
import type { PlutusScript, Data } from "@meshsdk/core";
import { CardanoWallet, MeshBadge, useWallet } from "@meshsdk/react";

import plutusScript from "../data/plutus.json";
import { useState } from "react";
import cbor from "cbor";

enum States {
  init,
  locking,
  lockingConfirming,
  locked,
  unlocking,
  unlockingConfirming,
  unlocked,
}

const koiosProvider = new KoiosProvider('preprod');



export default function Home() {
  const [state, setState] = useState(States.init);

  const { connected } = useWallet();

  return (
    <div className="container">
      <Head>
        <title>DEMO</title>
        <link
          href="https://meshjs.dev/css/template.css"
          rel="stylesheet"
          key="mesh-demo"
        />
      </Head>

      <main className="main">
        <h1 className="title">
          CONNECT WALLET AND CLICK UNLOCK BUTTON
        </h1>

        <div className="demo">
          {!connected && <CardanoWallet />}

          {connected &&
            state != States.locking &&
            state != States.unlocking && (
              <>
                {(state == States.init || state != States.locked) && (
                  <Lock setState={setState} />
                )}
                <Unlock setState={setState} />
              </>
            )}
        </div>

        {connected && (
          <div className="demo">
            {(state == States.locking || state == States.unlocking) && (
              <>Creating transaction...</>
            )}
            {(state == States.lockingConfirming ||
              state == States.unlockingConfirming) && (
                <>Awaiting transaction confirm...</>
              )}
          </div>
        )}

      </main>

    </div>
  );
}

// this bs is from the template
function Lock({ setState }) {
  async function lockAiken() {}
  return (<button type="button" onClick={() => lockAiken()}>No Click</button>);
}

//
// this handles the sc interaction
// follow this to get an idea on how to do this
//
function Unlock({ setState }) {

  // the wallet we need
  const { wallet } = useWallet();

  // the script we are spending from
  const script: PlutusScript = {
    code: cbor
      .encode(Buffer.from(plutusScript.validators[1].compiledCode, "hex"))
      .toString("hex"),
    version: "V2",
  };

  
  // click unlock aiken button
  async function unlockAiken() {
    setState(States.unlocking);

    // the tx we are going to build

    // hardcode for demo
    const scriptRefTxId = "026ac222531e98efcd2950a12baba80af409a9fa8d359119435c48e6be7ceff0";
    const scriptRefTxIdx = 1;
    const scriptAddress = "addr_test1zrfg36fqc5g6xwz2j2jqw074wlmax4dw3vgel7rhw9h47ydl4gu9er4t0w7udjvt2pqngddn6q4h8h3uv38p8p9cq82qkqs555";
    console.log("Script Address", scriptAddress);

    // get the wallet change address
    const changeAddress = await wallet.getChangeAddress();
    console.log("Change Address", changeAddress);

    // we use the empty datum on the utxo
    const datum: Data = {
      alternative: 0,
      fields: [],
    };
    const datumHash = resolveDataHash(datum);
    console.log("Datum Hash", datumHash);

    // get contract utxos and search for the one with the same datum hash
    // this will neeed to be the round robin part where the utxo selection
    // is based off of our choice
    // const contractUTxOs = await fetchAddressUtxos([scriptAddress]);
    const contractUTxOs = await koiosProvider.fetchAddressUTxOs(scriptAddress);
    let contractUTxO = contractUTxOs.find((utxo: any) => {
      return utxo.datum_hash === datumHash;
    });
    console.log("Contract UTxO", contractUTxO);

    
    // [{ unit: policyId + tokenName, quantity: "1" }]

    // get the wallet utxos to see what to lock
    // this is either a user selection or a look up
    // from list kind of thing.
    // the asset we are going to lock
    // hardcoded for now
    const targetUnit = "0409e2e893b11527311de4455cf699127b71b7870754a8a493c5edfb4c54";
    const targetPid = "0409e2e893b11527311de4455cf699127b71b7870754a8a493c5edfb";
    const targetTkn = "4c54";
    const targetAmt = 123321;

    // contract
    type Asset = {
      unit: string;
      quantity: string;
    };
    
    let contractAssets: Asset[] = [];
    contractUTxO.asset_list.forEach(asset => {
      console.log(asset);
      if (asset.policy_id === targetPid) {
        // policy id and asset name are strings
        // quanity and amt needs to be ints added then converted back to a string
        let quantity = parseInt(asset.quantity, 10) + targetAmt;
        contractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: quantity.toString()})
      } else {
        contractAssets.push({unit: asset.policy_id + asset.asset_name, quantity: asset.quantity})
      }
    });
    // [{ unit: policyId + tokenName, quantity: "1" }]

    // we need the users utxos now
    const walletUTxOs = await wallet.getUtxos();
    const collateralUTxOs = await wallet.getCollateral();
    const collateralUTxO = collateralUTxOs[0]
    console.log(collateralUTxOs);
    
    // get all the utxos with that token and hope for the best that the change works
    let filteredUTxOs = walletUTxOs.filter((utxo) => {
      // Check if the utxo contains the targetPid
      const containsTargetUnit = utxo.output.amount.some((asset) => {
        return asset.unit === targetUnit;
      });
      // Check if the utxo only has lovelace
      const hasOnlyLovelace = utxo.output.amount.length === 1 && utxo.output.amount[0].unit === 'lovelace';

      // Check if either condition is satisfied
      return containsTargetUnit || hasOnlyLovelace;
    
    });
    console.log("Wallet UTxO", filteredUTxOs);

    // this will be the token to lock
    const redeemer = {
      list: [
        {
          alternative: 0,
          fields: [
            {"bytes": targetPid},
            {"bytes": targetTkn},
            {"int": targetAmt},
          ]
        }
      ]
    };

    console.log("Connect to Provider");

    /// NOW BUILD THE TX
    const mesh = new MeshTxBuilder({
      fetcher: koiosProvider,
      submitter: koiosProvider,
      evaluator: koiosProvider,
    });
    console.log("Building Tx");

    mesh
      .changeAddress(changeAddress)
      .txInCollateral(collateralUTxO.input.txHash, collateralUTxO.input.outputIndex)
      .spendingPlutusScriptV2()
      .txIn(contractUTxO.tx_hash, contractUTxO.tx_index)
      .txInInlineDatumPresent()
      .txInRedeemerValue(redeemer)
      .spendingTxInReference(scriptRefTxId, scriptRefTxIdx)
      .txOut(scriptAddress, contractAssets)
      .txOutInlineDatumValue(datum);
    
    // add in the users inputs
    filteredUTxOs.forEach(utxo => {
      mesh.txIn(utxo.input.txHash, utxo.input.outputIndex);
    });
    // user outputs should be handled by change address
    console.log("Complete Tx");

    await mesh.complete();
    const signedTx = mesh.completeSigning()
    console.log(signedTx);


  }

  return (
    <button type="button" onClick={() => unlockAiken()}>
      Unlock Asset
    </button>
  );
}
