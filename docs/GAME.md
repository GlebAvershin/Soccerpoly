# Footbolapolia — The World Draft

**Pitch:** Football club ownership as a quick, social table game. Pick a route, sign clubs around a miniature world and build league sets before the final whistle.

The football action is decision-making: choosing transfers, collecting clubs by league and investing in a stadium. The visual fantasy is a daylight tabletop stadium, with toy footballers, a relief world map, directional motion and a TV scoreboard. The board lists 15 real clubs across five divisions, with three clubs per division. Players are original characters.

## Continental Cup rules, v0.6

- One table, up to six humans. Solo starts with two bots. Human players join in the lobby before kickoff. A late arrival watches the current match and can play next. A disconnected seat becomes a bot for the remaining season. No elimination.
- Eight rounds. Every manager starts on Kickoff with 700 free match credits. Each turn reveals a short route (1–3) and a long route (4–6); their destination is shown before the player commits.
- Landing on a free club offers a signing. An opponent's club collects gate revenue, capped by your balance. Landing on your own club offers the first stadium level. A complete three-club league unlocks level 2, doubles its gate revenue and adds 160 to portfolio value.
- Crossing Kickoff pays 140 CR. Goal and Offside have independent decks and reshuffle separately. Goal cards pay a bonus. Offside cards deduct credits or send the manager to the bench. On the next turn, the short route is available for free, or 50 CR reopens the normal route choice.
- Old Trafford and Santiago Bernabéu are independent properties. TV Rights and Kit Deal are commercial properties. Owning both in either group doubles the fee for that group. Free properties use the same purchase and auction flow as clubs.
- Before moving, open a property you own and sell it back to the bank once per turn. The bank pays 60% of the listed value rounded down, plus 50% of stadium upgrades. The property becomes free and stops contributing to the old owner's group. The turn clock keeps running.
- A property can go to an eight-second sealed auction. Each player can pass or bid the full price or 75% rounded up to 5 CR. The highest bid wins. Ties follow turn order starting after the player who opened the auction. The winner pays their bid. The portfolio uses the listed property value.
- Matchday offers a guaranteed 75 CR or a shot with three possible results. The chance of a goal is 3/6, a save 2/6, and offside 1/6. A goal awards 140 CR and one cup. The safe move is the timeout default.
- Ranking is cash + listed property value + invested capital + complete-league bonuses + 80 per cup. Ties share the title. Every action that costs credits displays the cost. Match credits reset each match and cannot be bought.
- The main panel teaches the next decision; rules and a club ledger are optional. Desktop and touch supported; no claim of console certification.

## Technical contracts

The server owns RNG, timers, turn state, balances and ownership. A client submits only a verb and an exact state revision. The server checks sender, phase, verb, revision, funds and per-player traffic before mutation. Snapshots carry public data only. An auction has a stable token and public response flags. The server holds the bid amounts until it commits the result. A local render layer handles camera, pawn motion, stadiums, trophies and sound. The shuffled deck stays on the server and only resolved cards appear in public snapshots. The server generates the static board. No persistent player data or commerce is needed for the slice.

Acceptance: clean build, rule tests and repeated seed simulation; actual Studio join/start/move/action/results smoke; document remaining device/live network, age reach and product gates. See RELEASE.md and QA.md.
