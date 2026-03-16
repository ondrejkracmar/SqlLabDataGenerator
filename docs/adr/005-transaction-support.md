# ADR-005: Transaction-Based Rollback for Data Generation

## Status
Accepted

## Date
2025-01-01

## Context
Data generation inserts into multiple tables in FK dependency order. If generation fails mid-way (e.g., on the 5th of 10 tables), previously inserted data creates an inconsistent state — parent tables have data but child tables are incomplete.

## Decision
Add `-UseTransaction` switch to `Invoke-SldgDataGeneration` that wraps all table inserts in a single database transaction:

- **SQL Server**: Transaction is passed to `SqlBulkCopy` constructor and all `SET IDENTITY_INSERT` commands
- **SQLite**: External transaction is passed to `Write-SldgSqliteData`, which uses it instead of creating a local one
- **Rollback**: On any table failure, the entire transaction is rolled back and all previously inserted rows are removed
- **Commit**: Only after all tables succeed does the transaction commit

The switch is opt-in to preserve backward compatibility — default behavior remains auto-commit per table.

## Consequences
- **Positive**: Guarantees all-or-nothing data generation — no partial/inconsistent states.
- **Positive**: Opt-in design means no breaking change for existing users.
- **Negative**: Large transactions hold locks longer, which may impact concurrent database access.
- **Negative**: SQL Server `SqlBulkCopy` with external transactions cannot use internal batching optimizations.
- **Negative**: Transaction log growth may be significant for very large generation runs.
