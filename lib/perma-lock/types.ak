// redeemer just needs to add in more tokens
// use a debug for testing since its a perma lock
pub type Redeemer {
  AddTokens { add_amt: Int }
  Debug
}
