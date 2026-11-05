# ADR-0001: Record architecture decisions

- Status: Accepted
- Date: 2026-11-05
- Deciders: Shadman Arko

## Context
The project uses many tools. Without recorded reasoning, choices look arbitrary and are hard to revisit.

## Options considered
1. No formal records: fast, but knowledge is lost.
2. Wiki pages: easy to write, drift from the code.
3. ADRs in the repo: versioned with the code, reviewable in PRs.

## Decision
Use ADRs in `docs/02-adr/`, one per significant decision, reviewed through pull requests.

## Consequences
Small overhead per decision; clear history and a strong talking point for design reviews.
