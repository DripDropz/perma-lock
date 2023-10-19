use aiken/transaction.{ScriptContext, Spend}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/count
use assist/find
use assist/payout
use perma_lock/types.{AddTokens, Debug, Redeemer}

validator(locking_pid: PolicyId, locking_tkn: AssetName) {
  fn params(
    inbound_datum: Void,
    redeemer: Redeemer,
    context: ScriptContext,
  ) -> Bool {
    when context.purpose is {
      Spend(output_reference) ->
        when redeemer is {
          AddTokens { add_amt } -> {
            // the transaction being validated
            let tx = context.transaction
            let this_input = find.input_by_ref(tx.inputs, output_reference)
            let this_addr = this_input.output.address
            // The value on the sale utxo, we need this for the change calculation
            let this_value = this_input.output.value
            let returning_value =
              value.add(this_value, locking_pid, locking_tkn, add_amt)
            // the datum going back to the queue contract
            expect outbound_datum: Void =
              find.output_datum_by_addr(tx.outputs, this_addr)
            and {
              // just continue the datum
              (inbound_datum == outbound_datum)?,
              // add the value to the contract
              payout.exact(this_addr, returning_value, tx.outputs)?,
              // single sale script input
              count.inputs_by_addr(tx.inputs, this_addr, 1),
              // one sale script output
              count.outputs_by_addr(tx.outputs, this_addr, 1),
            }
          }
          // set false in production, true in testing
          Debug -> False
        }
      // any other purpose fails
      _ -> False
    }
  }
}
