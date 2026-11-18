# Как играть в Soccerpoly v0.24.2

Вы управляете футбольными клубами на поле из 32 клеток. Стол рассчитан на четверых, свободные места занимают боты. Каждый начинает с **2 000 кредитов (CR)**. Хост выбирает быстрый матч на 20 минут или длинный на 60. На обычное решение даётся 15 или 30 секунд соответственно. [Играть в Roblox](https://www.roblox.com/games/114770772027261/Soccerpoly)

## Первая партия

1. Выберите футболиста и начните матч. При первом запуске лобби открывается на английском. Кнопка **Language · EN** переключает игру на русский.
2. В свой ход бросьте два кубика. Фигурка проходит сумму выпавших очков, за проход старта вы получаете **200 CR**. Дубль даёт дополнительный бросок, третий дубль подряд отправляет на скамейку.
3. На свободном клубе откроется карточка покупки. Можно выбрать уровень стадиона или пропустить покупку. Например, «Атлетико» стоит **120 CR** и приносит **30 CR** за визит соперника. С первым улучшением покупка стоит **220 CR**, а аренда становится **100 CR**. Нажмите на любую клубную клетку, чтобы посмотреть её цены.
4. На чужой клетке аренда списывается автоматически. После оплаты игра может предложить выкуп. Полная лига, щит или максимальный уровень клуба защищают владельца от выкупа.
5. Соберите четыре клуба одной лиги, чтобы удвоить их аренду. На скамейке можно заплатить **50 CR** или попытаться выбросить дубль. Если денег на платёж не хватает, откроется выбор между продажей имущества и банкротством.

На телефоне кнопка **К ходу** приближает камеру к активному футболисту. **Всё поле** возвращает обзор. [Поле на телефоне](../art/studio-overview-ru-v0242.png) · [Карточка покупки](../art/studio-dossier-ru-v0242.png)

## Сделки и особые клетки

- **Сделка.** Перед броском откройте свой клуб в списке собственности. Выберите соперника и предложите продажу или обмен. За ход можно сделать одно предложение. Цена продажи составляет 90, 100 или 110 % номинала. При обмене участник, получающий более дорогой клуб, доплачивает разницу. На ответ отводится до шести секунд в пределах текущего хода. Улучшение у любого клуба соответствующей лиги блокирует сделку.
- **Выездной тур.** В следующий ход выберите клетку назначения. Там сработают обычные правила, включая покупку или аренду.
- **Шанс.** Возможны карта события, щит, спонсорские 110 CR или выход на удар.
- **Чемпионат.** Возьмите гарантированные **75 CR**, назначьте свой клуб хозяином чемпионата с двойной арендой или пробейте по воротам. На решение есть восемь секунд. Гол приносит **140 CR и кубок** с вероятностью 3/6, сейв — **25 CR** с вероятностью 2/6, офсайд стоит **40 CR** с вероятностью 1/6. По тайм-ауту игрок получает гарантированный бонус.

## Как выиграть

Досрочно побеждает игрок, который собрал три полные лиги, все покупаемые клетки одной стороны или все четыре стадиона. Побеждает также последний платёжеспособный игрок. Если время вышло, к остатку CR прибавляются номинал собственности, вложения в улучшения, **160 за полную лигу** и **80 за каждый кубок**. Поэтому при одинаковом балансе наличных один игрок может опережать другого.

[Каталог клубов и цен](../src/shared/TourBoard.luau) · [Тесты условий победы](../tests/tour.test.luau)

## Архив правил версии с двумя маршрутами

# Soccerpoly — The World Draft

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
