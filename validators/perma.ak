use aiken/transaction.{ScriptContext, Spend}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/count
use assist/find
use assist/payout
use perma_lock/types.{AddTokens, Debug, Redeemer}

// compile the validator for a specific policy id and asset name to lock permanently
validator(lock_pid: PolicyId, lock_tkn: AssetName) {
  fn params(_datum: Void, redeemer: Redeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // spend only
      Spend(output_reference) ->
        // we want to add tokens and have the ability to debug for testing
        when redeemer is {
          //
          // add more lock token to the utxo
          //
          AddTokens { add_amt } -> {
            // the entire transaction
            let tx = context.transaction
            // this input being validated
            let this_input = find.input_by_ref(tx.inputs, output_reference)
            // this address being spent from
            let this_addr = this_input.output.address
            // this value on the input
            let this_value = this_input.output.value
            // calculate that value returning to the script
            let that_value = value.add(this_value, lock_pid, lock_tkn, add_amt)
            // the datum going back to the queue contract; implicit data validation
            // this silent fails for anything coming back that isn't Void
            expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
            //
            // add some tokens and send it back to the contract
            //
            and {
              // only can add tokens to the value
              add_amt > 0,
              // send exact value back to the contract
              payout.exact(this_addr, that_value, tx.outputs),
              // single script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // single script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
            }
          }
          //
          // set False in production, True in testing
          //
          Debug -> True
        }
      // anything else fails
      _ -> False
    }
  }
}
