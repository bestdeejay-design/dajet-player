# КОНТЕКСТ-БЛОК ARENA — волна «доки»: согласование README/ROADMAP/ кодом

> Релей: координатор → ARENA (исполнитель), ревью — SZ (super-z).
> Репозиторий: **`bestdeejay-design/dajet-player`** — и только он.
> Источник: аудит #18 (SZ, read-only), находки
> **AUD-01, AUD-04, AUD-05, AUD-06, AUD-07, AUD-11, AUD-13, AUD-14**.
> База: свежий `main` — **`9b340114`** (коммит брифа SZ-01; код
> `Sources/`/`Tests/` на этом коммите).
> Ветка: **любая в префиксе `arena/`** — Arena создаёт её сама от
> свежего `main` (как делала для #13: `arena/<session-id>-…`). SZ не
> назначает имя; единственное граничное условие — ветка в `arena/` и
> базируется на актуальном `main`. Перед стартом — `git pull`, сообщи
> координатору свежий HEAD; если `main` уехал — ребейсь.
> Форма: один PR, только документы. Прав на issue у ARENA есть, на merge —
> нет (merge по ревью SZ + слову владельца).

## Репо и база

- репозиторий: `bestdeejay-design/dajet-player`
- старт: свежий `main`, база-хэш на момент постановки — `9b340114cfa007a5284cd0650c90a0e1c02d1851`
- твоя ветка: любая в префиксе `arena/` (создаёшь сама от свежего `main`; имя — на твой session-id, как для #13)
- тип волны: **только документы** — `README.md`, `README.ru.md`, `ROADMAP.md`.
  Ни одного символа в `Sources/`, `Tests/`, `build.sh`, `.github/`, `Icon/`,
  `Installer/`, `media/`, `Package.swift`, `VERSION`, `NOTES.md`,
  `CHANGELOG.md` **не трогать**.

## Задача одной строкой

Свести README/README.ru/ROADMAP к коду по 8 находкам аудита: версия,
список фреймворков, поведение бокового меню, мёртвые ссылки, статус
релиза/иконки, число тестов, тулчейн.

## Почему так

Аудит #18 (read-only, SZ, база `ebad790`) нашёл 14 расхождений; 8 из них —
чисто документационные. Код правилен, документы отстали. Эта волна закрывает
все 8 одним PR, не трогая код, — и заодно прогоняет контур
ARENA → сборка → ревью SZ на самом безопасном материале, прежде чем браться
за plist (AUD-02) и тесты ядра (AUD-03).

После merge #19 (remember-folder) база актуальна: `main` уже включает 5 новых
тестов `RememberFolderTests` — значит «7 регрессионных тестов» в ROADMAP
устарело ещё сильнее (теперь 16).

## Что сделать по шагам

Каждая находка — где править, что не так, чем подтверждено (`файл:строка`),
какой должна стать. **Текст прозы пишет ARENA** — ниже направление, не
готовые строки. Ревью SZ сверяет прозу с кодом по ссылкам.

**AUD-01 — версия.**
Файлы: `README.md:13`, `README.ru.md:13` (раздел «Where it is» / «Где мы
сейчас»), `ROADMAP.md:11` (блок «Текущее состояние»).
Сейчас: открываются «**v0.4.0** — …».
Реальность: `VERSION:1` = `0.1.0`; `NOTES.md:1` = «Dajet Player 0.1.0»;
`build.sh:112` → `CFBundleShortVersionString = 0.1.0`; `CHANGELOG.md:178` =
«## 0.1.0 — 2026-10-12»; `ROADMAP.md:13` сам подтверждает: «текущий тег
проекта в VERSION — 0.1.0». «v0.4.0» — имя волны, протекшее в версию.
Направление: убрать семвер-префикс `v0.4.0` из прозы, поставить фактический
релизный тег `0.1.0`. Само описание состояния волны сохранить.
**Не bump `VERSION`** — это релизное решение владельца, не этой волны.
Проверка: `rg -n 'v0\.4\.0' README.md README.ru.md ROADMAP.md` — пусто.

**AUD-04 — список фреймворков.**
Файл: `README.md:41`.
Сейчас: «SwiftUI and AVFoundation, and nothing else — no third-party
dependencies».
Реальность (`Sources/DajetPlayer/`): `AppKit`, `SwiftUI`, `AVFoundation`,
`Combine`, `CoreGraphics`, `CoreImage`, `Foundation`, `ImageIO`,
`MediaPlayer`, `UniformTypeIdentifiers`. AppKit (`NSStatusItem`/`NSMenu`/
`NSOpenPanel`/`NSVisualEffectView`) и `MediaPlayer`
(`MPRemoteCommandCenter`/`MPNowPlayingInfoCenter`) — load-bearing.
Дух zero-dep верен (CI: `build.yml:70-73`), буква приуменьшает.
Направление: расширить до «Only Apple's frameworks» с перечислением реально
используемых (SwiftUI, AppKit, AVFoundation, MediaPlayer, и системные
image/Uniform-Type API). Zero-dep-claim сохранить.
`README.ru.md:41` — синхронно поправить (там зеркало).

**AUD-05 — боковое меню описано старым drawer-поведением.**
Файлы: `README.md:15`, `README.md:49` (P-10), `README.md:51` (P-06R),
`README.ru.md:15`, `ROADMAP.md:17`.
Сейчас: «comes out of the window's leading edge on one spring» /
«comes out over the player rather than pushing it aside» /
«slides out … on the spring … pull the edge to bring it out» /
ROADMAP «колонка на узком окне — оверлем поверх плеера».
Реальность: `App.swift:22-35` (комментарий issue #15) и `App.swift:173` —
`NavigationSplitView`, колонка — элемент split, «it can never be over the
player again», системный divider/анимация.
Направление: переписать на «колонка — элемент split-view, рядом с плеером,
никогда поверх него (issue #15); окно само растёт до обоих». Убрать
«spring» / «pull the edge» / «over the player» — этого в коде нет.

**AUD-06 — мёртвая ссылка на `Motion.glide`.**
Файлы: `ROADMAP.md:21` (`Design.swift`: «пружины
`Motion.glide`/`settle`/`quick`») и `ROADMAP.md:23` (`Side.swift`:
«выезжает на `Motion.glide`»).
Реальность: `Design.swift:191-194` — «the column's own glide … is gone
with the drawer it moved». `Motion` содержит только `settle` и `quick`
(`Design.swift:202-207`), `glide` нет.
Направление: убрать `Motion.glide` из ROADMAP; ссылаться на системную
анимацию split-view и `Motion.settle`/`Motion.quick` там, где они реально
используются.
Проверка: `rg -n 'Motion\.glide' ROADMAP.md` — пусто.

**AUD-07 — «Чего нет: Релиза» устарело.**
Файл: `ROADMAP.md:35`.
Сейчас: «Релиза: dmg, zip, appcast, Homebrew tap».
Реальность: `build.sh:143-211` строит dmg+zip+appcast; `release.sh`
публикует GitHub Release (тег `v${VERSION}-dajet`); `tap.sh` толкает cask
в `homebrew-tap`. Чего реально нет — **нотаризация** (`build.sh:20-22`:
«notarisation is the release wave's business») и то, что скрипты ни разу
не запускались (тег `v0.1.0-dajet` не существует в `git ls-remote`).
Направление: перенести в «Чего нет» только «notarization» и «release не
опубликован (скрипты не запущены)»; scaffolding отметить как есть.

**AUD-11 — тулчейн в ROADMAP пинит несуществующее.**
Файл: `ROADMAP.md:26`.
Сейчас: «CI: macOS 15, Swift 6.1.2, Xcode 16.4».
Реальность: `.github/workflows/build.yml:28-35` тулчейн **не пинит** —
печатает через `::notice` (`sw_vers`/`swift --version`/`xcodebuild -version`).
Направление: либо убрать конкретные версии из ROADMAP («macOS 15 runner,
актуальные Swift/Xcode — см. notice в CI»), либо указать, что версии
динамические. **Не пинить их в `build.yml`** — это отдельное решение, вне
этой волны.

**AUD-13 — число тестов.**
Файл: `ROADMAP.md:11`.
Сейчас: «Presentation.swift и 7 регрессионных тестов — на месте».
Реальность после merge #19: `Tests/DajetPlayerTests/` = `PresentationTests`
(7) + `NativeWindowTests` (4) + `RememberFolderTests` (5) = **16**.
Направление: поправить на 16 (или убрать число и оставить ссылку на
`swift test`, чтобы не дрейфить).

**AUD-14 — «Фирменный .icns» устарело.**
Файл: `ROADMAP.md:33`.
Сейчас: «Фирменный `.icns` (assets/ заморожены)».
Реальность: `Icon/icon.swift` рисует иконку кодом (канон волны),
`build.sh:76-77` пишет `AppIcon.icns` (по данным координатора — 148 KB,
10 entries, `edge=1.00`). Заморожены только `Assets.car` (Dark/Tinted Dock
— только при Xcode 26, `build.sh:91-100` fallback).
Направление: `.icns` отметить как есть; в «Чего нет» оставить только
`Assets.car` (Dark/Tinted Dock).

## Вне области

- **Не трогать код.** Только `README.md`, `README.ru.md`, `ROADMAP.md`.
- **Не bump `VERSION`** (`VERSION`, `NOTES.md`, `CHANGELOG.md`, `build.sh` —
  не трогать). Бамп версии — релизное решение владельца.
- **Не пинить тулчейн в `build.yml`** (AUD-11 — только ROADMAP-строка; пин в
  CI — отдельная волна SZ-03).
- **Не заводить issue по находкам** — координатор заведёт; эта волна работает
  от брифа, не от issue.
- Не трогать чужие репозитории (`brand`, `dajet-browser`, `joer`,
  `homebrew-tap`).
- Не запускать `release.sh`/`tap.sh`.
- Не переоценивать принятые волны P-03…P-06R, P-09, P-10, P-10R.
- Не трогать описание PR #19 / remember-folder — это уже в `main`.

## Definition of Done

- Все 8 находок закрыты в `README.md`/`README.ru.md`/`ROADMAP.md`; ни одного
  изменения вне этих трёх файлов (`git diff --stat main..HEAD` — ровно
  три строки).
- Версия в шапках README/ROADMAP = `0.1.0`; «v0.4.0» нигде не встречается
  (`rg -n 'v0\.4\.0' README.md README.ru.md ROADMAP.md` — пусто).
- Список фреймворков в README/README.ru включает AppKit и MediaPlayer;
  zero-dep-claim сохранён.
- Боковое меню описано как split-view (issue #15), без «spring» /
  «pull the edge» / «over the player».
- `Motion.glide` не встречается (`rg -n 'Motion\.glide' ROADMAP.md` —
  пусто).
- «Чего нет» в ROADMAP = notarization + release не опубликован;
  `Assets.car` (Dark/Tinted) — вместо «Фирменный .icns».
- Число тестов = 16 (или нет числа).
- Тулчейн в ROADMAP — не пинит несуществующие версии.
- `swift test` на ветке = 16/16 (не должно измениться — код не тронут;
  прогон — для уверенности).
- PR открыт, база `main`, ревью SZ по verbatim-выводу сборки.

## Форма сдачи

- ветка в префиксе `arena/` (имя — на твой session-id, как для #13), PR
  «docs: align README/ROADMAP/VERSION with code (AUD-01..AUD-14 docs subset)»;
- тело PR: список закрытых находок `AUD-NN` со ссылками на `файл:строка`
  до/после;
- в комментарии PR — verbatim-вывод:
  `git rev-parse HEAD` (база),
  `git diff --stat main..HEAD`,
  `rg -n 'v0\.4\.0' README.md README.ru.md ROADMAP.md`,
  `rg -n 'Motion\.glide' ROADMAP.md`,
  `swift test` (16/16);
- ревью SZ — по этому выводу; merge — по слову владельца.

## Правила

- вопросы — до начала, через координатора;
- доказательство — `файл:строка` или команда с выводом; «кажется» не
  принимается;
- prose пишет ARENA — SZ даёт направление, не готовые строки; ревью SZ
  проверяет сходство с кодом, не стилистические предпочтения;
- `git status` чистый на выходе (только коммит в твою `arena/`-ветку);
- существующие контракты и принятые волны не переоценивать;
- если что-то в брифе не сходится с кодом по указанным строкам —
  остановиться и спросить, не додумывать.
