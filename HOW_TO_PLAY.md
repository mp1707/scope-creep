# Scope Creep — How to Play

## Goal

Survive 5 sprints. By the end you must have shipped at least one Major Feature and hired a Backend Dev without going bankrupt, drowning in bugs, or burning everyone out.

## The Board

You start with 18 cards arranged on an office desk. Drag cards around freely. Zoom with scroll, pan by dragging empty space.

Hover over any card to read what it does.

## Sprints

Each sprint lasts **60 seconds**. The countdown is shown top-left. When time runs out, the board resolves automatically:

1. **Salaries** are paid — 1 Money per Developer or QA on the board
2. **Shipped work** converts to Money (Quick Win = 2, Major Feature = 6)
3. **Untested Release Candidates** become Bugs
4. **Tech Debt** spawns Bugs (every 2 Debt = 1 new Bug)
5. **Focus resets** on all workers
6. **Deadline** attaches to the leftmost unfinished Spec or Release Candidate

## Recipes — Stack Cards to Combine Them

Drag a work item onto a worker to start a recipe. A progress bar appears above the stack. When it fills, both cards transform into something new.

| Stack this… | …on this | Time | Cost | Result |
|---|---|---|---|---|
| Quick Win Request | Product Owner | 4s | — | Quick Win Spec |
| Big Bet Request | Product Owner | 5s | — | Big Feature Spec |
| Client Request | Product Owner | 4s | — | Quick Win Spec (70%) or Big Feature Spec (30%) |
| Quick Win Spec | Fullstack Dev | 8s + 1s/Debt | 1 Focus | Release Candidate |
| Quick Win Spec | Frontend Dev | 7s + 1s/Debt | 1 Focus | Release Candidate |
| Big Feature Spec | Frontend Dev | 8s + 1s/Debt | 1 Focus | Frontend Build |
| Big Feature Spec | Backend Dev | 8s + 1s/Debt | 1 Focus | Backend Build |
| Frontend Build + Backend Build | each other | instant | — | Release Candidate (Major) |
| Big Feature Spec | Fullstack Dev | 12s + 1s/Debt | 2 Focus | Release Candidate + **Tech Debt** |
| Release Candidate (Quick Win) | QA Tester | 5s | 1 Focus | Shipped Quick Win |
| Release Candidate (Major) | QA Tester | 7s | 1 Focus | Shipped Major Feature |
| Tech Debt | Fullstack Dev | 6s | 1 Focus | *(removed)* |
| Tech Debt | Backend Dev | 5s | 1 Focus | *(removed)* |
| Bug | QA Tester | 5s | 1 Focus | *(removed)* |
| Bug | Fullstack Dev | 3s | 1 Focus | *(removed)* + **Tech Debt** |
| Coffee | any Worker | instant | — | Restores 1 Focus |
| Burnout card | Coffee card | 5s | — | Clears Burnout |
| 2 Money | Business Opportunity | instant | 2 Money | 2 Client Requests |
| 3 Money | Hire Market | instant | 3 Money | New Developer |

Dragging a card off a stack cancels any recipe in progress.

## Focus

Each worker has **2 Focus** per sprint, shown as pips on their card. Recipes that cost Focus consume a pip when they complete. A worker forced to work at 0 Focus generates a **Burnout** card nearby.

Burned-out workers have only 1 Focus next sprint and work slower (+2s on all tasks).

## Coffee Machine

Passively produces 1 Coffee every 20 seconds (max 2 on the board at once). Use Coffee to restore Focus before a worker hits zero, or drop a Burnout card onto a Coffee to clear it in 5 seconds.

## Hiring

Drop 3 Money cards onto the **Hire Market** card. First hire is always a Backend Dev, second is a Fullstack Dev, subsequent hires are random.

## Lose Conditions (immediate)

- **Bankruptcy** — Money hits 0 at sprint end and can't cover salaries
- **Bug overload** — 4 Bugs on the board at once
- **Burnout crisis** — 3 Burnout cards on the board at once

## Win Condition

Survive 5 sprints having:
- Shipped at least 1 Major Feature
- Hired at least 1 Backend Dev
- Never triggered a lose condition
