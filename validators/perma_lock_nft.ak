use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{Value}
use assist/count
use assist/find
use assist/payout
use assist/types.{Token}

type Tokens =
  List<Token>

/// Add a list of Token types to a Value type. This should be a very safe way to
/// increment a value on a UTxO. The other option is having the redeemer be 
/// the general Value type and potentially allow badly formed values to be used.
///
/// ```aiken
/// add_tokens_to_value(redeemer.tokens, this_value)
/// ```
fn add_tokens_to_value(the_value: Value, tokens: Tokens) -> Value {
  when tokens is {
    // take a token and add it to the value
    [tkn, ..rest] ->
      // only can add tokens to this value
      if tkn.amt > 0 {
        let new_value: Value = value.add(the_value, tkn.pid, tkn.tkn, tkn.amt)
        add_tokens_to_value(new_value, rest)
      } else {
        fail @"Token Addition Failed"
      }
    // return the value
    [] -> the_value
  }
}

// redeemer for adding assets of type Tokens
type Redeemer {
  assets: Tokens,
}

validator(
  // allows many nft locking contracts to exist
  _random_string: ByteArray,
) {
  fn params(_datum: Void, redeemer: Redeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // spend only
      Spend(output_reference) -> {
        // This brings `assets` into scope.
        let Redeemer(assets) = redeemer
        // the entire transaction
        let tx: Transaction = context.transaction
        // this input being validated
        let this_input: Input = find.input_by_ref(tx.inputs, output_reference)
        // this address being spent from
        let this_addr: Address = this_input.output.address
        // this value on this input
        let this_value: Value = this_input.output.value
        // calculate that value returning to this address
        let that_value: Value = add_tokens_to_value(this_value, assets)
        // that datum must go back this address; implicit data validation
        // this silent fails for anything coming back that isn't the Void type
        expect _: Void = find.output_datum_by_addr(tx.outputs, this_addr)
        //
        // add a token to this value and send that value back to the contract
        //
        and {
          // single script input
          count.inputs_by_addr(tx.inputs, this_addr, 1),
          // single script output
          count.outputs_by_addr(tx.outputs, this_addr, 1),
          // send at least that value back to this address
          // ada can change here!
          payout.at_least(this_addr, that_value, tx.outputs),
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
