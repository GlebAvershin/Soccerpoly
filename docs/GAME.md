# Правила Footbolapolia v0.13.0

Матч рассчитан на четверых. Фигурка идёт на сумму двух кубиков. Дубль даёт дополнительный бросок, а третий подряд отправляет на скамейку. На скамейке можно заплатить 50 CR или бросить на дубль. За проход старта начисляется 200 CR.

На покупке клуба можно сразу выбрать уровень постройки. Посещение чужого актива списывает аренду. После оплаты некоторые клубы можно выкупить. Щит защищает клуб от выкупа. Соперник может принять продажу или обмен, предложенные до броска.

Выездной тур позволяет выбрать пункт назначения на следующий ход. На клетке «Чемпионат» можно пробить по воротам, взять 75 CR или назначить свой клуб хозяином чемпионата, чтобы удвоить его аренду. На клетке «Шанс» выпадает карта, щит, спонсорский бонус в 110 CR или удар.

На решение об ударе игроку даётся до 8 секунд. По тайм-ауту начисляется гарантированный бонус. Гол выпадает с вероятностью 50% и приносит 140 CR и кубок. Сейв приносит 25 CR, офсайд стоит 40 CR. Кубок добавляет 80 CR к итоговой стоимости активов.

При нехватке денег нужно продать имущество или объявить банкротство. Победа засчитывается за три полные лиги, все активы одной стороны, четыре стадиона или как последнему платёжеспособному игроку. По истечении времени побеждает первый по сумме денежных средств, активов и кубков. Хост выбирает в лобби быстрый формат на 20 минут с 15 секундами на стандартное решение или длинный на 60 минут с 30 секундами на решение.

[Разбор референса](ART_DIRECTION.md).

## Архив правил версии с двумя маршрутами

# Footbolapolia — The World Draft

**Pitch:** Football club ownership as a quick, social table game. Pick a route, sign clubs around a miniature world and build league sets before the final whistle.

The football action is decision-making: choosing transfers, collecting clubs by league and investing in a stadium. The visual fantasy is a daylight tabletop stadium, with articulated football figures, a central pitch, readable screen-space labels and a broadcast-style scoreboard. The board lists 15 real clubs across five divisions, with three clubs per division. Players are original characters.

## Continental Cup rules, v0.7.1

- One table, up to six humans. Solo starts with two bots. Human players join in the lobby before kickoff. A late arrival watches the current match and can play next. A disconnected seat becomes a bot for the remaining season. No elimination.
- Eight rounds. Every manager starts on Kickoff with 700 free match credits. Each turn reveals a short route (1–3) and a long route (4–6); their destination is shown before the player commits.
- Landing on a free club offers a signing. An opponent's club collects gate revenue, capped by your balance. Landing on your own club offers the first stadium level. A complete three-club league unlocks level 2, doubles its gate revenue and adds 160 to portfolio value.
- Crossing Kickoff pays 140 CR. Goal and Offside have independent decks and reshuffle separately. Goal cards pay a bonus. Offside cards deduct credits or send the manager to the bench. On the next turn, the short route is available for free, or 50 CR reopens the normal route choice.
- Old Trafford and Santiago Bernabéu are independent properties. TV Rights and Kit Deal are commercial properties. Owning both in either group doubles the fee for that group. Free properties use the same purchase and auction flow as clubs.
- Before moving, open a property you own and sell it back to the bank once per turn. The bank pays 60% of the listed value rounded down, plus 50% of stadium upgrades. The property becomes free and stops contributing to the old owner's group. The turn clock keeps running.
- Before moving, offer one eligible club per turn for another club or for 90%, 100%, or 110% of its listed price, rounded down. In a swap the player taking the higher-price club pays the difference in listed value. The invited player can accept or decline. Funds and ownership are validated at settlement. An offer lasts at most six seconds within the route clock and closes as soon as its sender moves. New offers need at least three seconds remaining on that clock. Club deals are also available with bots.
- Clubs in a league with stadium upgrades are tied to that league until the upgrades are sold. A manager can sell the upgrades at one club to the bank for half of their listed construction cost and keep the club. This uses the same once-per-turn bank sale allowance.
- A figure power can be activated once per season before moving. Mika pays 20 CR to change the short destination by one square (3 steps becomes 2). Inez earns 45 CR on her next shot on target, including a save. Kai earns 50 CR next time he crosses Kickoff. Amara reduces her next payable visiting fee by up to 50 CR. Rafa receives 30 CR for signing a club, including at auction, or saves 50 CR on a stadium upgrade, whichever comes first. Samira cancels an Offside card or earns 50 CR on a Goal card, whichever she draws first. Triggered powers resolve automatically.
- A property can go to an eight-second sealed auction. Each player can pass or bid the full price or 75% rounded up to 5 CR. The highest bid wins. Ties follow turn order starting after the player who opened the auction. The winner pays their bid. The portfolio uses the listed property value.
- Matchday offers a guaranteed 75 CR or a shot with three possible results. The chance of a goal is 3/6, a save 2/6, and offside 1/6. A goal awards 140 CR and one cup. The safe move is the timeout default.
- Ranking is cash + listed property value + invested capital + complete-league bonuses + 80 per cup. Ties share the title. Every action that costs credits displays the cost. Match credits reset each match and cannot be bought.
- The main panel teaches the next decision; rules and a club ledger are optional. Desktop and touch supported; no claim of console certification.

## Technical contracts

The server owns RNG, timers, turn state, balances and ownership. A client submits a verb, a state revision and any required choice identifiers. The server checks sender, phase, verb, revision, funds and per-player traffic before mutation. The server sends pending deal terms only to the two parties. A reply uses a token bound to its offer. Completed deals are public. An auction has a stable token and public response flags. The server holds the bid amounts until it commits the result. A local render layer handles camera, pawn motion, stadiums, trophies and sound. The shuffled deck stays on the server and only resolved cards appear in public snapshots. The server generates the static board. No persistent player data or commerce is needed for the slice.

Acceptance: clean build, rule tests and repeated seed simulation; actual Studio join/start/move/action/results smoke; document remaining device/live network, age reach and product gates. See RELEASE.md and QA.md.
