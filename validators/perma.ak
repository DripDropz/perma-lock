use aiken/transaction.{ScriptContext, Spend}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/count
use assist/find
use assist/payout
use perma_lock/types.{AddTokens, Debug, Redeemer}

validator(locking_pid: PolicyId, locking_tkn: AssetName) {
  fn params(_datum: Void, redeemer: Redeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // spend only
      Spend(output_reference) ->
        when redeemer is {
          // add more of the locking token onto the utxo
          AddTokens { add_amt } -> {
            // the transaction
            let tx = context.transaction
            // the input being validated
            let this_input = find.input_by_ref(tx.inputs, output_reference)
            let this_addr = this_input.output.address
            let this_value = this_input.output.value
            // calculate the value returning to the script
            let returning_value =
              value.add(this_value, locking_pid, locking_tkn, add_amt)
            // the datum going back to the queue contract; implicit data validation
            expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
            // make sure to add something and send it back to the contract, one at a time
            and {
              // only can add something
              add_amt > 0,
              // add the value to the contract
              payout.exact(this_addr, returning_value, tx.outputs),
              // single sale script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // one sale script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
            }
          }
          // set false in production, true in testing
          Debug -> True
        }
      // any other script purpose fails
      _ -> False
    }
  }
}
