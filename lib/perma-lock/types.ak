// redeemer just needs to add in more tokens but we need to
// use a debug for testing since its a permanently locking contract
pub type Redeemer {
  // the add amount needs to be positive
  AddTokens { add_amt: Int }
  // testing only debug redeemer
  Debug
}
