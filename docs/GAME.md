# Footbolapolia — The World Draft

**Pitch:** Football club ownership as a quick, social table game. Pick a route, sign clubs around a miniature world and build league sets before the final whistle.

The football action is decision-making: choosing transfers, collecting clubs by league and investing in a stadium. The visual fantasy is a nighttime tabletop arena, with toy footballers, a relief world map, directional motion and a TV scoreboard. Brands and players are original; geographic city names supply recognition. The rules and presentation are authored for this game.

## v0.1 design contract

- One table, up to four humans. Solo starts immediately with two bots; a second human may join before kickoff. A late arrival watches the current match and can play next. A disconnected seat becomes a bot for the remaining season. No elimination.
- Eight rounds. Every manager starts on Kickoff with 700 free match credits. Each turn reveals a short route (1–3) and a long route (4–6); their destination is shown before the player commits.
- Landing on a free club offers a signing. An opponent's club collects gate revenue, capped by your balance. Landing on your own club offers two levels of stadium investment. A complete three-club league doubles all of its gate revenue and adds 160 to portfolio value.
- Kickoff crossing pays 140. Broadcast, Sponsor, Matchday and Final Whistle cells have explicit values; Tactics cards are drawn for free. No trading, auctions, mortgages, or debt.
- Ranking is cash + acquisition cost + invested capital + complete-league bonuses. Ties share the title. Every action that costs credits displays the cost. Match credits reset each match and cannot be bought.
- The main panel teaches the next decision; rules and a club ledger are optional. Desktop and touch supported; no claim of console certification.

## Technical contracts

The server owns RNG, timers, turn state, balances and ownership. A client submits only a verb and an exact state revision. The server checks sender, phase, verb, revision, funds and per-player traffic before mutation. Snapshots carry public data only. A local render layer handles camera, pawn motion and sound; the server generates the static board. No persistent player data or commerce is needed for the slice.

Acceptance: clean build, rule tests and repeated seed simulation; actual Studio join/start/move/action/results smoke; document remaining device/live network, age reach and product gates. See RELEASE.md and QA.md.
