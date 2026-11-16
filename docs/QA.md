# Release evidence · v0.1

Tested locally on macOS with Roblox Studio 0.747.0.7471481, Rojo 7.7.1 and Luau 0.747. Studio tests use a separate local place and synthetic inputs to make results reproducible. The release does not embed the test clients.

| Check | Evidence |
| --- | --- |
| Rules, compilation and build | `make verify`; strict type check of the pure catalog and rules, compilation of all Luau source, successful Rojo build. |
| Rules scenarios | Scripted cases cover the wrong turn, invalid action, a purchase, opponent revenue, crossing Kickoff, affordability, a free Tactics draw, a complete league multiplier, stadium upgrades, capping a fee at balance and rejection after game-over. |
| Seeded simulation | 800 seasons with 2, 3 or 4 seats. All finished, no negative balances, valid positions and sorted final scores. Longest: 47 accepted actions. 140 completed league sets across the sample. Bot-only data checks mechanics and pacing bounds, not engagement, balance between humans or commercial viability. |
| Solo Studio | One real Studio Client DataModel plus bots through lobby, choosing a figure, choosing a route, buying a club, all eight rounds, final table and return to lobby. Stale and duplicate requests do not mutate the purchase. The test checks instantiated HUD controls and sends gameplay inputs through the real RemoteEvent. |
| Two-client Studio | Two separate Studio clients and a local server play a complete season and share the synchronized final and lobby. Actions pass through the same server intent handler as release. |
| Touch layouts | Studio Device Simulator: iPhone XR portrait and 640 × 300 landscape. The scenarios verify active controls are at least 40 px tall and inside the HUD safe area in both orientations. This is not device latency, frame-rate or physical touch certification. |

## Before public release

- Run the signed-off package in a distinct cloud playtest with human players, including a four-person table; verify join while in progress, quit during a contract, and restart.
- Observe first-time players with touch, track comprehension and time to first route, check a lower-tier Android and an actual iPhone over slow connections. Verify frame time, memory, clipping and sound.
- Verify live Analytics in Creator Hub. No measured D1/D7, ad return, revenue or mobile benchmark exists yet.
- Check content questionnaire, asset ownership, audience rights, discoverability and public name. Private publishing and sales are separate actions.
