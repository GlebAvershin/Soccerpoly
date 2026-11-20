# Soccerpoly · Мировой Драфт

Пошаговая футбольная стратегия для Roblox. Менеджеры покупают клубы, торгуются на аукционах и в событии Continental Cup выбирают между гарантированной выплатой и ударом по воротам.

**[Открыть игру](https://www.roblox.com/games/114770772027261/Soccerpoly)** · [Скачать сборку для Roblox Studio](dist/Soccerpoly.rbxl) · [Технологии и исходники](docs/TECHNOLOGIES.md) · [Проверки на мобильных экранах](docs/QA.md)

![Игровое поле Soccerpoly](art/promo/game_banner.png)

## Как AI использовался в разработке

Codex помог подготовить двуязычное событие Continental Cup и его проверки. Python компилирует проверенный каталог в Luau, а отдельный инструмент на C++17 пересчитывает экономику. В опубликованном событии игрок может получить **75 кредитов** гарантированно. В более позднем эксперименте четыре модели оценили альтернативы и выбрали **84 кредита**. Эти два решения можно сверить по материалам выпуска и независимым вердиктам. [История разработки](docs/AI_WORKFLOW.md) · [Релиз v10](docs/RELEASE.md) · [Исходный каталог](content/continental-cup.json) · [Как протестировать инструмент дизайнера](docs/CUP-TRIAL.md)

## Поле и фигурки Continental Cup · версия Roblox 10

![Шесть игровых фигурок в форме сборных](art/matchday-roster.png)

У каждого футболиста свой силуэт и цикл бега. Исходники фигурок, формы и поз собраны в [сцене Blender](art/matchday-roster.blend). У 32 клеток доски отдельные иллюстрации, подписи и цены. В открытом досье клуба используется рисунок большего размера. По краям поля стоят крытые трибуны и четыре угловых павильона.

[Видеообзор двух игр](art/design-reel/Game-Editions.mp4) · [Поле на телефоне](art/programme/board-print-phone.png) · [Доска в Roblox Studio](art/programme/board-print-studio.png) · [Досье клуба крупным планом](art/programme/club-print-studio.png) · [Трибуны и павильоны в Blender](art/stadium-kit.blend)

## 🌟 Ключевые инженерные решения и инновации

<table align="center">
  <tr>
    <td width="30%" align="center">
      <img src="art/promo/game_icon.png" width="220" alt="Soccerpoly Icon"/><br/>
      <b>Official Place Icon</b>
    </td>
    <td width="70%">
      <ul>
        <li><b>Авторитетный сервер и снапшот-репликация:</b> Вся игровая математика, генерация случайных чисел, аукционы и валидация ходов выполняются строго на сервере в иммутабельной функциональной модели. Клиенты получают компактные дельта-снапшоты и выполняют сглаженный предиктивный рендеринг.</li>
        <li><b>Zero-External-Asset Blender Pipeline:</b> 3D-модели стадионов 4 уровней (флаг, академия, арена, мегастадион), а также скульптированные головы и формы 6 мировых звезд футбола запечены в бинарные Luau-буферы. Игра полностью автономна и не зависит от модерации внешних мешей Roblox.</li>
        <li><b>Ортонормированная кинематика пешек (IK & Bones):</b> Устранено сжатие и деформация сетки конечностей за счет применения строгого ортонормированного базиса <code>CFrame.fromMatrix</code>, анатомической фиксации плеч и шеи, а также процедурного дыхания.</li>
      </ul>
    </td>
  </tr>
</table>

---

## 🏟️ Визуальный стиль и интерактивное окружение

![Стадионные ассеты в Blender Cycles](art/blender-stadium-kit.png)

* **Медиакуб стадиона (Live Stadium Jumbotron):**
  Над северными трибунами арены воздвигнута 30-метровая стальная ферма с широкоформатным LED-дисплеем (`SurfaceGui`, `LightInfluence = 0`). Экран в реальном времени транслирует фазы матча (`ROLL THE DICE`, `TRANSFER AUCTION`, `PENALTY SHOOTOUT`, `CONTINENTAL CHAMPION`), имя активного менеджера, цвет его клуба, текущего лидера по капиталу и бегущую строку лиги.
* **Строительные искры (VFX BuildSparks):**
  При покупке клуба или повышении клубного уровня на клетке поля вспыхивает динамический фейерверк золотых искр в фирменном цвете команды.
* **Свободная камера (Free Orbit & Zoom):**
  Игрок может свободно вращать стол правой кнопкой мыши или тачем (`targetYaw`, `targetPitch`), зумировать колесом (`targetZoom`) с физической кинематической интерполяцией и сбрасывать ракурс кнопкой `⟲`.
* **Аудио-ландшафт с Ducking:**
  Шины `SoundGroup` (Music, Stadium Crowd, Effects) с эквалайзером и автоматическим sidechain-приглушением музыки на 9 dB при ключевых событиях (гол, банкротство, дубль, финальный свисток).

---

## 🎮 Социальные и мета-игровые механики

```mermaid
graph TD
    Match[Матч Continental Cup] -->|Победы / Поражения / Баланс| Career[CareerStore: DataStoreService]
    Career -->|XP & Уровни| Unlocks[Разблокировка косметики]
    Career -->|Ежедневный вход| Streak[Серия входов: 1-7+ дней]
    Career -->|События на поле| Quests[Ежедневные контракты: 3 квеста]
    
    Unlocks --> Dice[Скины кубиков: Carbon, Cyber, Gold, Obsidian]
    Unlocks --> Auras[Ауры хода: Mint, Flame, Radiance, Halo]
    
    VIP[VIP Sponsor Pass] -->|+25% XP Boost| Career
    VIP -->|Эксклюзив| Obsidian[Кубики Obsidian Gold & Аура Champion's Halo]
    
    Match -->|Эмоции на поле| Emotes[Быстрые эмодзи над пешками: ⚽ 🔥 🏆 👏 😱 😂]
```

1. **Карьера тренера (Career & Locker):**
   * Сохранение статистики через `DataStoreService` (`PlayerCareerV1`): сыгранные матчи, победы, кубки, заработанный капитал, серия входов.
   * Система уровней менеджера на основе прогрессивной шкалы опыта ($Level = \lfloor\sqrt{XP / 120}\rfloor + 1$).
2. **Ежедневные контракты (Daily Quests):**
   * Сервер автоматически ротирует 3 ежедневных задания («Сыграть 1 матч», «Подписать 2 клуба», «Улучшить 1 стадион») с выдачей наград в окне карьеры.
3. **Быстрые эмодзи (Pawn Emotes):**
   * Боковая панель с 6 реакциями (⚽, 🔥, 🏆, 👏, 😱, 😂), всплывающими в 3D-пространстве над головой фигурки с плавной анимацией покачивания и затухания.
4. **Монетизация (VIP Sponsor Pass):**
   * Интеграция `MarketplaceService` с возможностью приобретения VIP-пропуска, дающего бонус +25% к опыту тренера и легендарный комплект «Золотой Обсидиан».

---

## 📐 Архитектура проекта

```mermaid
flowchart LR
    subgraph Client["Клиент (Luau)"]
        Input["Сенсор / Мышь"] --> Controller["Table.client.luau"]
        Controller --> TableView["Arena.luau (3D World & Camera)"]
        TableView --> Jumbotron["Live Jumbotron Screen"]
        TableView --> Pawns["Pawn.luau (IK & Anim)"]
        TableView --> Dice["TableDice.luau (Physics)"]
        Controller --> Audio["TableAudio.luau (Ducking)"]
    end

    subgraph Network["Сетевой уровень (ReplicatedStorage)"]
        Intent["RemoteEvent: Intent"]
        Snapshot["RemoteEvent: Snapshot"]
        CareerEvent["RemoteEvent: CareerAction"]
        EmoteEvent["RemoteEvent: EmoteAction"]
    end

    subgraph Server["Сервер (Roblox ServerScriptService)"]
        MatchServer["Match.server.luau (Authority)"]
        RulesEngine["Rules.luau (Pure Functional)"]
        CareerStore["CareerStore.luau (DataStoreService)"]
        Telemetry["Telemetry.luau (Analytics)"]
    end

    Input --> Intent
    Intent --> MatchServer
    MatchServer --> RulesEngine
    RulesEngine --> Snapshot
    Snapshot --> Controller
    CareerEvent <--> CareerStore
    EmoteEvent <--> MatchServer
    MatchServer --> Telemetry
```

### Структура каталогов

| Каталог / Файл | Назначение |
| --- | --- |
| `src/server/Match.server.luau` | Серверный цикл матча, сетевой арбитраж, таймеры, боты, валидация |
| `src/server/CareerStore.luau` | `DataStoreService`, профили игроков, квесты, VIP, сохранение прогресса |
| `src/server/World.luau` | Процедурная сборка арены, ночное освещение, прожекторы, Джамботрон |
| `src/client/Arena.luau` | Рендерер 3D-сцены, свободная орбитальная камера, Джамботрон, эффекты |
| `src/client/Pawn.luau` | Ортонормированный скелет пешек, позы, анимация бега, warp, дыхание |
| `src/client/TableDice.luau` | Физика броска кубиков, эмаль, инкрустация, 5 стилей скинов |
| `src/client/TableAudio.luau` | Звуковые эффекты, `SoundGroup`, эквалайзер, sidechain ducking |
| `src/client/Table.client.luau` | Главный контроллер интерфейса, окно карьеры, карточки клубов, эмодзи |
| `src/client/Copy.luau` | Локализация интерфейса (Русский / Английский) |
| `src/shared/Board.luau` | Топология доски (32 клетки, 20 клубов, 5 лиг, 4 стадиона) |
| `src/shared/Rules.luau` | Чистая математическая модель правил (покупка, аренда, дубли, банк) |
| `scripts/render_promo.py` | Headless-рендер промо-иконки и баннеров в Blender Cycles |
| `scripts/studio-qa.py` | Автоматизированный запуск тестов в реальном Roblox Studio |

---

## 🧪 Верификация и тестирование

Проект покрыт многоуровневой системой тестов: от проверки типов Luau до симуляций Монте-Карло и сквозных тестов в реальном движке Roblox Studio.

### 1. Компиляция и симуляции баланса (`make test`)
```bash
PATH="$PWD/.tools/bin:$PATH" make test
```
* **57 000 строк кода Luau** в строгом режиме (`--strict`).
* **4 320 сезонов** симуляции рыночной экономики и карточек событий.
* **800 парных сидов**: детерминированное выравнивание шансов победы между фигурами (винрейт каждого персонажа строго в пределах $16.67\% \pm 0.8\%$).

### 2. Сквозные тесты в Roblox Studio (`scripts/studio-qa.py`)
```bash
# Мобильный смоук-тест матча на эмулированном iPhone 7 (русская локализация)
python3 scripts/studio-qa.py --rojo .tools/bin/rojo --device portrait-small --edition ru --matchday

# Арт-тест мешей, текстур и анимаций
python3 scripts/studio-qa.py --rojo .tools/bin/rojo --art
```
Оба теста проходят со статусом `WORLD DRAFT QA PASS WorldDraftSmoke`.

---

## 🚀 Сборка проекта

Для сборки релизного файла плейса используется [Rojo](https://rojo.space/):

```bash
# Сборка бинарного плейса .rbxl
PATH="$PWD/.tools/bin:$PATH" rojo build -o dist/Soccerpoly.rbxl

# Запуск локального сервера синхронизации со Studio
PATH="$PWD/.tools/bin:$PATH" rojo serve
```

Полученный файл `dist/Soccerpoly.rbxl` открывается в Roblox Studio и готов к публикации в один клик.

---

## 👨‍💻 Автор

**Глеб Авершин**  
* GitHub: [@GlebAvershin](https://github.com/GlebAvershin)
* Проект: [Soccerpoly Repository](https://github.com/GlebAvershin/Soccerpoly)
* Плейс на Roblox: [Soccerpoly Experience](https://www.roblox.com/games/114770772027261/Soccerpoly)
