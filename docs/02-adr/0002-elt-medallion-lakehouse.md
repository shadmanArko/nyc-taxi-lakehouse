# ADR-0002: ELT with a medallion lakehouse

- Status: Accepted
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
We must turn raw trip files into trusted daily revenue, keep raw data for reprocessing, and make every transformation testable and auditable.

## Options considered
1. **ETL in Python/pandas** (the original reference solution): simple, but transformations are hard to test at the data level, raw data is not preserved in a queryable form, and it does not scale past one machine.
2. **ELT into a warehouse/lakehouse with layered models (medallion)**: raw data preserved, SQL transformations versioned and tested, reprocessing is cheap.

## Decision
ELT with Bronze (raw), Silver (clean), Gold (business) layers. Load raw first; transform inside the lakehouse with SQL.

## Consequences
- Raw data is always available for reprocessing and audits.
- Business logic lives in SQL models with tests.
- Requires a lakehouse engine and a transformation tool (ADR-0003, ADR-0004).
