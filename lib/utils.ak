use aiken/interval.{Finite}
use aiken/transaction.{ValidityRange}

pub fn get_lower_bound(range: ValidityRange) -> Int {
  expect Finite(lower_bound) = range.lower_bound.bound_type
  lower_bound
}
