# Разработка Soccerpoly на новом компьютере

Первый результат — локальный матч на четверых. Для него нужны Git, Roblox Studio и Rojo 7.7.1. Исходники моделей, подготовленные текстуры и модули Luau уже есть в репозитории. Личный аккаунт Roblox подходит для локальной разработки. Права на опубликованную игру нужны для выпуска обновлений.

## 1. Получить исходники

Установите Git и Roblox Studio, один раз запустите Studio и войдите в свой аккаунт. Studio поддерживает Windows и macOS. Linux подходит для сборки и автоматических тестов. [Установка Roblox Studio](https://create.roblox.com/docs/studio/setup)

В терминале выполните:

```sh
git clone https://github.com/GlebAvershin/Soccerpoly.git
cd Soccerpoly
```

Команды ниже выполняются из корня с файлом `default.project.json`. Для разработки используйте `main`. Для воспроизведения конкретного релиза переключитесь на тег командой `git switch --detach v0.24.2`.

## 2. Собрать и открыть игру

### Windows · PowerShell

Пример для Windows x64. На Windows ARM64 замените в имени архива `x86_64` на `aarch64`. Команды устанавливают CLI внутри локальной копии проекта. [Официальные архивы Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1)

```powershell
New-Item -ItemType Directory -Force .tools/bin, dist | Out-Null
Invoke-WebRequest 'https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-windows-x86_64.zip' -OutFile .tools/rojo.zip
Expand-Archive .tools/rojo.zip .tools/bin -Force
$env:Path = (Resolve-Path .tools/bin).Path + ';' + $env:Path
rojo --version
rojo build -o dist/Soccerpoly.rbxl
```

### macOS · Terminal

Пример автоматически выбирает архив для Apple Silicon или Intel. Git и инструменты сборки Apple можно установить через `xcode-select --install`.

```sh
mkdir -p .tools/bin dist
arch=$(uname -m)
if [ "$arch" = arm64 ]; then arch=aarch64; fi
curl -fL "https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-macos-${arch}.zip" -o .tools/rojo.zip
unzip -o .tools/rojo.zip -d .tools/bin
chmod +x .tools/bin/rojo
export PATH="$PWD/.tools/bin:$PATH"
rojo --version
rojo build -o dist/Soccerpoly.rbxl
```

Чтобы сверить сборку из тега v0.24.2 с релизом, выполните `Get-FileHash dist/Soccerpoly.rbxl -Algorithm SHA256` в PowerShell или `shasum -a 256 dist/Soccerpoly.rbxl` в Terminal. SHA-256 опубликованного файла — `564f7d747401a43522c1eb5098c80972cfb656fadee52b461edba82a5e5bd6e1`.

Ожидаемый вывод команды `rojo --version` — `Rojo 7.7.1`. В **File → Open from File** откройте `dist/Soccerpoly.rbxl` и нажмите **Play**. Сервер создаёт поле при запуске. Появится английское лобби. Выберите фигурку, начните матч и бросьте кубики. Три свободных места займут боты. Правила и примеры цен приведены в [руководстве игрока](GAME.md).

## 3. Внести первую правку через Rojo

1. На `main` создайте рабочую ветку, например `git switch -c feature/club-caption`.
2. Выполните `rojo plugin install` и перезапустите Studio, если плагин ещё не появился. Затем в корне проекта запустите `rojo serve` и оставьте терминал открытым. [Установка плагина](https://rojo.space/docs/v7/getting-started/installation/)
3. Откройте **локальный** файл из шага 2. В режиме редактирования выберите **Plugins → Rojo → Connect**. Стандартный адрес — `localhost:34872`. При первом подключении проверьте предложенные изменения. [Синхронизация со Studio](https://rojo.space/docs/v7/getting-started/new-game/)
4. Для проверки измените текст русской подписи в `src/client/Copy.luau`, сохраните файл, запустите **Play** и выберите русский язык. После **Stop** можно редактировать дальше. Серверные модули и созданная при старте арена перечитываются при следующем запуске матча.
5. Храните изменения в файлах репозитория. Перед коммитом соберите новый place и проверьте `git diff`. Каталоги `.tools/` и `dist/` используются для локальных инструментов, логов и сборок. В новом терминале снова добавьте `.tools/bin` в PATH командой для своей ОС из шага 2.

## 4. Где менять поведение

| Задача | Точка входа | Как проверить |
| --- | --- | --- |
| Добавить клуб или изменить цену | [TourBoard.luau](../src/shared/TourBoard.luau) задаёт порядок и экономику. [BoardLabels.luau](../src/client/BoardLabels.luau) задаёт короткие EN/RU-подписи. [Geometry.luau](../src/shared/Geometry.luau) определяет физическое положение клеток. | Проверить покупку и аренду, открыть досье клуба, посмотреть обе локализации в эмуляторе телефона. |
| Изменить ход, сделку или победу | [Rules.luau](../src/shared/Rules.luau) применяет действия к состоянию матча. Действующие сервер и клиент создают экземпляр правил через `Rules.withBoard(TourBoard, EventCards)`. | Запустить `luau tests/tour.test.luau`. Это тест текущего поля. Базовый `Board.luau` также используется в симуляциях предыдущего формата. |
| Изменить сетевое действие | [Match.server.luau](../src/server/Match.server.luau) проверяет участника, фазу и ревизию, проводит расчёт и рассылает снимок. [Table.client.luau](../src/client/Table.client.luau) отправляет намерение игрока и отображает ответ. | Проверить действие с двумя клиентами, включая устаревший ответ на сделку или действие вне очереди. |
| Отредактировать событие или исход удара | [continental-cup.json](../content/continental-cup.json) — источник текстов и наград. После правки выполнить `python3 scripts/event_studio.py compile` и включить обновлённый `src/shared/EventCards.luau` в тот же коммит. | `python3 scripts/event_studio.py check` проверяет согласованность каталога и генерации. На Windows можно использовать `py -3` вместо `python3`. |
| Изменить камеру, карточку, фигурку или звук | [Arena.luau](../src/client/Arena.luau), [PropertyCard.luau](../src/client/PropertyCard.luau), [Pawn.luau](../src/client/Pawn.luau), [TableAudio.luau](../src/client/TableAudio.luau). Исходные сцены и порядок экспорта собраны в [каталоге графики](../art/README.md). | Сыграть ход, открыть карточку и проверить возврат камеры из повтора. Для правок графики сравнить портретный и альбомный режимы. |

Rojo помещает общие модули в `ReplicatedStorage/League`, сервер в `ServerScriptService/Soccerpoly`, клиент в `StarterPlayer/StarterPlayerScripts/Soccerpoly`. Эта схема задана в [default.project.json](../default.project.json). Игровые деньги, RNG и часы принадлежат серверу. Параметры визуализации меняются на клиенте. Выбор языка сохраняется между сессиями в опубликованной игре. В локальном режиме Studio предпочтение действует в текущей сессии.

## 5. Проверить изменения

Для полного прогона на macOS нужны Make, Python 3.9+, C++17 и три программы из архива Luau 0.747. В терминале с настроенным Rojo выполните:

```sh
curl -fL https://github.com/luau-lang/luau/releases/download/0.747/luau-macos.zip -o .tools/luau.zip
unzip -o .tools/luau.zip -d .tools/bin
chmod +x .tools/bin/luau*
make verify
```

На Windows основной цикл сборки работает в PowerShell. Для проверки текущих правил распакуйте `luau-windows.zip` в `.tools/bin` и выполните `luau tests/tour.test.luau`. Полный `make verify` можно запустить в WSL2 Ubuntu x86_64. Установите `build-essential python3 curl unzip git` через apt. Внутри WSL клонируйте проект, распакуйте `rojo-7.7.1-linux-x86_64.zip` и `luau-ubuntu.zip` в `.tools/bin`, выполните `chmod +x .tools/bin/rojo .tools/bin/luau*`, добавьте каталог в PATH и запустите `make verify`. Те же архивы и контрольные суммы использует Linux CI. [Luau 0.747](https://github.com/luau-lang/luau/releases/tag/0.747) · [Workflow CI](../.github/workflows/quality.yml)

Успешный `make verify` завершается с кодом 0. Он проверяет контент, компиляцию и правила Luau, выполняет симуляции баланса, Python-тесты аналитики и C++-проверку экономики удара. Сборка появится в `dist/Soccerpoly.rbxl`, результаты аналитики — в `dist/analytics/`.

Для автоматической проверки в **Studio на macOS**:

```sh
python3 scripts/studio-qa.py --launchservices
python3 scripts/studio-qa.py --launchservices --device portrait-small --edition ru --matchday
```

Запускайте сценарии по очереди. Признак успеха — строка `WORLD DRAFT QA PASS WorldDraftSmoke`. Логи сохраняются в `.tools/`. На Windows этот же скрипт принимает `--studio` с полным путём к установленному `RobloxStudioBeta.exe`. Для ручного сетевого теста выберите **Server & Clients** в Studio и два клиента. Начните партию у хоста и проверьте, что покупка или аренда одинаково отображается в обоих окнах.

## Если запуск остановился

| Симптом | Что проверить |
| --- | --- |
| После клонирования папка `dist` пуста | Выполните шаг 2 либо скачайте готовый `.rbxl` из [релиза](https://github.com/GlebAvershin/Soccerpoly/releases/tag/v0.24.2). |
| `rojo` или `luau-compile` не найдены | Выполните `Get-Command rojo` в PowerShell или `command -v rojo` в Terminal. Проверьте распаковку и PATH в том терминале, откуда запускаете сборку. |
| Rojo подключён, но правка не появляется | Сверьте каталог в терминале, порт в плагине и имя открытого локального place. Остановите Play перед синхронизацией и начните новую сессию. |
| В опубликованной копии фигурки или карточки выглядят проще | Проверьте доступность **Enable Mesh / Image APIs** для владельца experience в Creator Hub. Для Soccerpoly v0.24.2 при выпуске переключатель был заблокирован до подтверждения возраста владельца. [Требования Roblox](https://create.roblox.com/docs/reference/engine/classes/EditableMesh) |

## Передача и публикация

Отправьте рабочую ветку на GitHub и откройте pull request в `main`. GitHub Actions запускает проверки и прикладывает сборку к прогону. Релизный тег фиксирует конкретные исходники, вложение GitHub Release содержит соответствующий `.rbxl`. Для облачного теста используйте отдельный тестовый experience. Публикация в рабочий Soccerpoly выполняется отдельно из проверенной сборки. [Порядок публикации и отката](RELEASE.md)
