# Soccerpoly · Technologies & Engineering Solutions

<p align="center">
  <a href="TECHNOLOGIES.md"><b>English</b></a> •
  <a href="TECHNOLOGIES.ru.md"><b>Русский</b></a>
</p>

In the turn-based football board game Soccerpoly, players balance risk and reward between a guaranteed safe payout and an uncertain shot on goal. This engineering case study demonstrates how game designers author seasonal LiveOps events, verify mathematical invariants, simulate macroeconomies across 100,000 matches, and deploy approved event catalogs into production Roblox builds. [Play on Roblox](https://www.roblox.com/games/114770772027261/Soccerpoly-Continental-Cup) · [Event Analysis](CONTINENTAL-CUP.md) · [Game Rules](GAME.md) · [Release Verification](RELEASE.md)

---

## 🎯 When to Recommend Taking a Shot

For the *Continental Cup* event, we evaluated every integer credit deficit a player might need to complete a property purchase in a single turn, ranging from 1 to 141 credits (CR):
* **1 to 75 CR deficit:** The guaranteed safe cashout (75 CR) always covers the target with 100% certainty.
* **76 to 140 CR deficit:** The guaranteed cashout falls short; only taking a shot on goal provides a viable path to purchase (3 out of 6 dice outcomes, **50.0% probability**).
* **141+ CR deficit:** Neither choice covers the shortage; the purchase must be deferred.

Every decision boundary and probability was independently verified against the `recommend_cash` function in Event Studio. The deterministic verification was executed via the AWS Agent Toolkit managed MCP server tool (`aws___run_script`) under the AWS Free tier with 0 billable resource API calls. [Receipts & Checksums](evidence/aws-toolkit.json) · [Audit Script](../studio/research/aws_audit.py) · [Replay Guide](https://github.com/GlebAvershin/lantern-atlas/blob/main/studio/research/README.md#aws-agent-toolkit-replay)

---

## ☁️ Cross-Service Verification via Cloud MCP Servers

1. **Amplitude MCP:** Retrieved 8 `game.study_evaluated` events filtered by game ID during research evaluation runs, including idempotency re-runs.
2. **Sentry MCP:** Queried issue **PYTHON-7** by event ID, verifying the `above_best_shot` trigger and `defer_purchase` guardrail decision.
3. **Databricks MCP (`system.ai.dbsql`):** Executed SQL analytical queries directly in cloud SQL warehouses. All 4 returned rows matched local SQLite calculations byte-for-byte.

[Query Parameters & SQL Evidence](evidence/service-mcp.json) · [Analytical SQL Queries](../studio/research/metrics.sql)

---

## 🔬 Reproducibility Verification

* **Luau Rule Suites:** Unit tests validated core tournament rules, turn progression, and currency balances.
* **Independent C++17 Calculation:** Deterministic STL calculator confirmed:
  - Goal Probability: **50.00%**
  - Expected Monetary Value of Shot (EV Cash): **71.667 CR**
  - Guaranteed Cashout (Safe Cash): **75.000 CR**
* **Cross-Engine Consistency:** SQLite and Databricks cloud warehouse produced identical results across all 4 research scenarios. Sentry and Amplitude ingestion records (5) verified HTTP 200 delivery. [Verification Results](evidence/replay-check.json) · [Replication Command](https://github.com/GlebAvershin/lantern-atlas/blob/main/studio/research/README.md#verifying-published-evidence)

---

## 📋 Decision Boundary Table (Continental Cup)

Event Studio answers: *"How much cash is missing to buy a club, and which action can deliver it in one turn?"*

| Missing Credits | Optimal Action | Probability of Covering Shortage |
| :---: | :--- | :---: |
| 1 – 75 CR | Take Guaranteed Payout | **100%** |
| 76 – 140 CR | Take a Shot on Goal | **50%** (3 of 6 outcomes) |
| 141+ CR | Defer Purchase | **0%** (No single-turn action covers target) |

---

## 📱 Responsive HUD Layout Generation via LLM & MCP

To adapt the game's interface across phones, tablets, and desktop monitors, a multi-model evaluation measured how reliably different models map designer briefs into responsive HTML/Luau layouts:

| Model / Method | Correct Placements | Execution Environment |
| :--- | :---: | :--- |
| Lexical Matching & Combinatorial Search | 4 / 6 | Python, Linux CI |
| Qwen2.5-0.5B Q4_K_M | 3 / 6 | llama.cpp, Linux CI |
| DeepSeek-R1-Distill-Qwen-1.5B Q4_K_M | 3 / 6 | llama.cpp, macOS ARM64 |
| Kimi-VL-A3B-Instruct Q3_K_S (Text Input) | 5 / 6 | llama.cpp, shared Linux runner |
| **EmbeddingGemma-300M (Bijective Assignment)** | **6 / 6 (100%)** | **ONNX Runtime, CPU** |

* **Layout Geometry:** Tested across 7 screen sizes in headless Chromium (including viewport breakpoint boundaries at 839px and 840px).
* **Accessibility Contrast:** C++20 tool evaluated UI palette: minimum contrast ratio reached **9.03**, exceeding the WCAG AA threshold of 4.5. [Cloud Action Run](https://github.com/GlebAvershin/Soccerpoly/actions/runs/44798032011) · [Geometry](evidence/hud/geometry.json) · [Contrast](evidence/hud/contrast.json)

---

## 🏆 Automated LiveOps «Champions Derby» Authoring & 100,000 Match Stress Test

To maintain seasonal LiveOps cadence, an end-to-end authoring and verification system connects generative models, deterministic C++17 balance invariant validators, and a 100,000-match economy simulation.

### 1. Automated Synthesis and Mathematical Invariant Enforcement

In `scripts/ai_event_author.py`, an automated pipeline synthesizes the bilingual **«Champions Derby»** event catalog:
1. Model generates card rules, shot outcomes, and localized flavor text.
2. Deterministic validator `event_studio.py` mathematically guarantees that goal odds do not exceed 50%, and safe cash (80 CR) is bounded by $[\text{Expected Cash}, \text{Expected Portfolio Value}]$.
3. Native C++17 tool `native/cup_preview.cpp` independently verifies probabilities and generates distribution outputs.

| Balance Metric | Continental Cup v1 | Champions Derby v1 (New LiveOps) | Invariant Status |
| :--- | :---: | :---: | :---: |
| **Goal Probability (Goal Odds)** | 50.0% (3 of 6 weight) | 50.0% (3 of 6 weight) | $\le 50.0\%$ (Satisfied) |
| **Expected Cash Value (EV Cash)** | 71.67 CR | 79.17 CR | C++17 Verified |
| **Total Value with Trophy (EV Portfolio)** | 111.67 CR | 124.17 CR | Trophy 90 CR Included |
| **Guaranteed Safe Payout (Safe Cash)** | 75.00 CR | 80.00 CR | $79.17 \le 80 \le 124.17$ (Satisfied) |
| **Card Deck Coverage** | 11 cards | 6 cards (foul, goal, bonus, scout, bench, VAR) | All archetypes covered |

[Generated Catalog](../content/champions-derby.json) · [Authoring Pipeline](../scripts/ai_event_author.py) · [Validation Receipt](evidence/liveops-derby.json)

---

### 2. 100,000-Match Macroeconomic Stress Test & Faucet/Sink Ratio

To prevent hyperinflation over 14-day seasons, `scripts/simulate_economy.py` simulated 100,000 tournament matches across 10,000 players, accounting for entry fees, tactical rerolls, and trophy acquisitions:

| Macroeconomy Metric | Continental Cup v1 (100k) | Champions Derby v1 (100k) | Target Balance Corridor |
| :--- | :---: | :---: | :---: |
| Currency Inflow (Faucet) | 11,028,175 CR | 11,506,295 CR | — |
| Currency Outflow (Sink) | 10,701,445 CR | 11,056,640 CR | — |
| **Inflation Ratio (Faucet / Sink)** | **1.0305** | **1.0407** | **1.00 — 1.15 (Healthy Economy)** |
| Median Wallet at Day 14 | 132.67 CR | 144.97 CR | Moderate progressive accumulation |
| Gini Wealth Inequality Coefficient | 0.4290 | 0.3910 | < 0.50 (Fair distribution) |
| Claimed Seasonal Trophies | 56,182 | 51,042 | High goal conversion rate |
| **Guardrail Alerting Status** | **PASSED** | **PASSED** | Zero anomalies in Sentry / Amplitude |

The simulation proves the Faucet/Sink ratio remains within **1.03–1.04**, driving consistent daily engagement without devaluing currency. [Simulation Script](../scripts/simulate_economy.py) · [Full Stress Test Report](evidence/economy-stress-test.json)

---

### 3. Multi-Agent Review Panel (LLM-as-a-Judge Consensus)

In `scripts/multi_agent_judge.py`, an automated consensus panel reviews newly authored events across 3 specialized agent personas via Databricks Model Serving (`databricks-qwen3-next-80b-a3b-instruct`):
1. **Chief Game Economy Auditor:** Audits inflation risk, Faucet/Sink parity, and exploit vectors.
2. **Player Experience & UX Director:** Analyzes clarity, emotional cadence, and defeat frustration.
3. **LiveOps & Retention Lead:** Evaluates trophy desirability and mid-term re-engagement.

The panel outputs a weighted **Production Performance Readiness Score (PPRS 0–100)**:
* **Critical Agent Insight:** Both events (`Continental Cup` at PPRS 52.0 and `Champions Derby` at PPRS 58.0) were flagged with `NEEDS_REVISION` due to offside penalties (-35 and -40 CR). The agents noted that harsh currency deductions on a low-probability roll (1 in 6) induce frustration in casual players, recommending a "streak bonus reset" mechanic rather than direct wallet clawbacks. [Audit Script](../scripts/multi_agent_judge.py) · [Verdict Protocol](evidence/multi-agent-judge.json)
