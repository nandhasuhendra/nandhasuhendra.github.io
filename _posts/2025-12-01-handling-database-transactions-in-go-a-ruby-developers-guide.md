---
title: "Handling Database Transactions in Go: A Ruby Developer's Guide"
description: "Coming from Ruby on Rails? Here's how database transactions work in Go — from basic commits and rollbacks to handling panics and nested transactions the Go way."
date: 2026-01-02
last_modified_at: 2026-01-02
author: Nanda Suhendra
categories:
  - General
tags:
  - Golang
  - Ruby on Rails
  - Design Pattern
cover_image:
canonical_url:
draft: false
---

As a Ruby developer, database transaction in Rails feels almost effortless: wrap some code in a `transaction` block, and Rails handles everything automatically.

In Go, without an ORM, handling transactions requires **explicit control**, especially when using **SQLc** package. In my first Go project, I needed to execute multiple repository operations as a single transaction, without the service layer knowing the database details and focus on the business logic.

In this post, I’ll share how I implemented a **transaction wrapper** that runs business logic safely as a single transaction, and the lessons I learned.

---

## The Real Problem

I need to perform a business operation that involved multiple steps only for publishing a Conversion Balance:

- Re-balancing temporary accounts for the debit and credit amount
- Update the amount for each temporary accounts
- Creating a transaction as an opening balance
- Update the real journal accounts based on temporary accounts balance
- Update the conversion balance status to publish

In Ruby, ActiveRecord makes this easy

```ruby
ActiveRecord::Base.transaction do
	conversion_balance.rebalance_tempoary_accounts(update: true)
	transaction = Transaction.create_from_conversion_balance(conversion_balance)
	conversion_balance.update(transaction_id: transaction.id, status: :published)
end
```

With Go + SQLc, repository functions are **single-query operations**, and calling them independently risk partial updates if one fails:

```go
conversionBalanceRepo.RebalanceTemporaryAccounts(ctx, cbModel, params)
trx := transactionRepo.CreateFromCB(ctx, cbModel)

cbModel.TransactionID = trx.ID
conversionBalanceRepo.Update(ctx, cbModel)
```

We need a way to run all repository calls **with single transaction**, without exposing transaction details to the service layer.

## The Solution: Transaction Wrapper

The concept of the database transaction is quite simple, just to make sure the queries are executed in **single database transaction**. The solution is create a **transaction wrapper** that:

1. Begins a transaction.
2. Accepts a business logic function to execute.
3. Commits the transaction if successful, or rollback on error

The service layer simply calls the wrapper with the business login — it doesn’t know about repositories or the database.

### Transaction Wrapper Example

```go
type DBTransaction struct {
	db *sql.DB
}

func NewDBTransaction(db *sql.DB) *DBTransaction {
	return &DBTransaction{db: db}
}

// Run executes the business logic within a single transactions
func (t *DBTransaction) RunWithTx(ctx context.Context, fn func(tx *sql.Tx) error) {
	tx, err := t.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}

	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	if err := fn(tx); err != nil {
		tx.Rollback()
		return err
	}

	return tx.Commit()
}
```

---

### Service Layer Usage

The service layer doesn’t know anything about repository how to start the database transaction. It just calls `RunWithTx` and passes the business logic as a function:

```go
func (cbs *conversionBalanceService) Publish(ctx context.Context, updateParams) error {
	return cbs.txWrapper.RunWithTx(ctx, func(tx *sql.Tx) error {
		conversionBalanceRepo := cbs.conversionBalanceRepo.WithTx(tx)
		transactionRepo := cbs.transactionRepo.WithTx(tx)

		// Rebalancing temporary accounts
		if err := conversionBalanceRepo.RebalanceTemporaryAccounts(ctx, cbModel, params); err != nil {
			return err
		}

		// Creating opening balance transaction
		trx, err := transactionRepo.CreateFromCB(ctx, cbModel)
		if err != nil {
			return err
		}

		// Updating conversion balance status
		cbModel.TransactionID = trx.ID
		if err := conversionBalanceRepo.Update(ctx, cbModel); err != nil {
			return err
		}
	}
}
```

**Key Points:**

- **Service layer** only initializes the wrapper and calls `RunWithTx` — it doesn’t handle transactions.
- **Transaction wrapper** handle commit and rollback
- **Business logic** run entirely inside the wrapper using the provided transaction.
- **Repositories** are injected inside the business logic using `WithTx(tx)`

---

## Lessons Learned

1. **Separation of concerns matters:** The service layer shouldn’t manage database transactions directly.
2. **Transaction wrapper centralizes control**: Commit, rollback, and error handling are handled in one place.
3. **Business logic is isolated**: The wrapper executes logic safely without leaking transaction details.
4. **Go is explicit**: Unlike Ruby, everything must be handled manually, but the design is safer and cleaner.

**Tips for Ruby developers moving to Go:**

1. Don’t mix service and transaction logic.
2. Encapsulate transaction handling in a wrapper.
3. Pass business logic as a function to run in the transaction.
4. Use repository wrappers (`WithTx`) inside the function.

---

## Conclusion

Transitioning from Ruby to Go taught me that explicitness isn’t a limitation — it’s a safeguard. Using a **transaction wrapper** allows the service layer to remain clean and unaware of database details while ensuring complex business operations run safely in a single transaction.

For Ruby developers moving to Go: embrace **transaction wrappers**. They separate concerns, reduce boilerplate, and make your business logic safer and easier to test.
