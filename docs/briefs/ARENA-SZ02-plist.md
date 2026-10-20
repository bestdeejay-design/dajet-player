# КОНТЕКСТ-БЛОК ARENA — волна «plist»: CFBundleDocumentTypes для аудиоформатов

> Релей: координатор → ARENA (исполнитель), ревью — SZ (super-z).
> Репозиторий: **`bestdeejay-design/dajet-player`** — и только он.
> Источник: аудит #18 (SZ, read-only), находка **AUD-02** (major).
> База: свежий `main` — **`e9abe1e8`** (merge PR #21, SZ-01 «доки»).
> Ветка: **любая в префиксе `arena/`** — Arena создаёт её сама от свежего
> `main` (как делала для #13: `arena/<session-id>-…` и для #21:
> `arena/9447817b-dajet-player`). SZ не назначает имя; единственное
> граничное условие — ветка в `arena/` и базируется на актуальном `main`.
> Перед стартом — `git pull`, сообщи координатору свежий HEAD; если `main`
> уехал — ребейсь.
> Форма: один PR, один кодовый файл (`build.sh`). Прав на issue у ARENA
> есть, на merge — нет (merge по ревью SZ + слову владельца).

## Репо и база

- репозиторий: `bestdeejay-design/dajet-player`
- старт: свежий `main`, база-хэш на момент постановки — `e9abe1e835551f9e24dbc5bbe7af1833d73f6978`
- твоя ветка: любая в префиксе `arena/` (создаёшь сама от свежего `main`;
  имя — на твой session-id, как для #13/#21)
- тип волны: **код, один файл** — `build.sh`. Ни одного символа вне
  `build.sh` **не трогать** (в частности — `Sources/`, `Tests/`, `Package.swift`,
  `README.md`, `README.ru.md`, `ROADMAP.md`, `VERSION`, `NOTES.md`,
  `CHANGELOG.md`, `.github/`, `Icon/`, `Installer/`, `media/`).

## Задача одной строкой

Добавить в генерируемый `Info.plist` (heredoc в `build.sh`) ключ
`CFBundleDocumentTypes` для аудиоформатов, которые плеер уже принимает
(`PlayerEngine.formats`), — чтобы аудиофайлы открывались двойным кликом в
Finder, через `open track.mp3`, «Open With» и назначением Dajet Player
дефолтным handler'ом. Сейчас работает только drag&drop + ⌘O.

## Почему так

Аудит #18 (read-only, SZ) нашёл: в `build.sh:102-122` генерируется
`Info.plist` без `CFBundleDocumentTypes` (grep по репо подтверждает —
ключ отсутствует). Для плеера это пропущенная primary-интеграция с
платформой: музыкальный файл, брошенный в Finder, не доходит до
приложения. README после SZ-01 уже не заявляет «drag&drop only», но
код всё ещё не объявляет типы. Это **major**-находка аудита.

Форматы, которые плеер реально принимает (`PlayerEngine.swift:77`):
`mp3, m4a, flac, wav, aiff, aif`. Это и есть набор, который надо
объявить в plist.

## Что сделать по шагам

### Шаг 1. Понять, где править

`build.sh:102-122` — heredoc, генерирующий `$APP/Contents/Info.plist`.
Между `NSHighResolutionCapable` и закрывающим `</dict>` нужно вставить
`CFBundleDocumentTypes`-блок. Шаблонная интерполяция `$NAME`/`$EXEC`/etc.
уже есть — у `CFBundleDocumentTypes` нет переменных, это статичный XML-блок.

### Шаг 2. Выбрать UTI для каждого формата

Целевая платформа — `MINIMUM="14.0"` (`build.sh:45`). UTI-стратегия:

| Расширение | UTI | Статус на macOS 14.0 |
|---|---|---|
| `mp3` | `public.mp3` | системный, стабилен |
| `m4a` | `public.mpeg-4-audio` | системный, стабилен |
| `wav` | `com.microsoft.waveform-audio` | системный, стабилен |
| `aiff`, `aif` | `public.aiff-audio` | системный, стабилен |
| `flac` | `public.flac` (или `org.xiph.flac`) | **нестабилен на 14.0..14.1** |

**Важно про flac:** `UTType.flac` (`public.flac`) Apple добавил только в
**macOS 14.2**. На целевой платформе 14.0 он может не резолвиться
системой. Два варианта:
- **(A) Объявить `UTImportedTypeDeclarations`** для flac с `conformsTo` =
  `public.audio` — тогда система знает flac даже на 14.0;
- **(B) Использовать `public.audio` как `LSItemContentTypes` для flac-**
  записи в `CFBundleDocumentTypes` — более грубо, но работает везде.

Arena выбирает сама — **(A) чище** (явное объявление), но если тест на
14.0..14.1 показывает, что `UTImportedTypeDeclarations` не подхватывается,
**(B) — рабочий fallback**. В брифе оставлено на решение Арены с
обязательной проверкой.

### Шаг 3. Минимальный блок CFBundleDocumentTypes

Один `CFBundleDocumentType` на все форматы (через массив
`LSItemContentTypes`), а не шесть записей. Примерная структура (Арена
пишет финальный XML, это направление):

```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Audio</string>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>LSHandlerRank</key>
    <string>Default</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>public.mp3</string>
      <string>public.mpeg-4-audio</string>
      <string>com.microsoft.waveform-audio</string>
      <string>public.aiff-audio</string>
      <string>public.flac</string>  <!-- или public.audio для 14.0 -->
    </array>
  </dict>
</array>
```

`CFBundleTypeRole` = `Viewer` (плеер читает, не редактирует).
`LSHandlerRank` = `Default` (претендует быть дефолтным handler'ом для этих
типов; macOS решает окончательно по своим правилам, но без этого ключа —
точно не претендует).

Если Arena выбрала вариант **(A)** для flac — перед
`CFBundleDocumentTypes` добавить `UTImportedTypeDeclarations`-блок для
`public.flac` (или `org.xiph.flac`) с `conformsTo` = `public.audio`,
`public.exported-type-declarations` — нет, импортируем чужой.

### Шаг 4. Не сломать существующее

- `build.sh:115` — `$ICONNAME` интерполируется в
  `<key>CFBundleIconName</key><string>AppIcon</string>` (или пустая строка).
  Вставлять `CFBundleDocumentTypes` **после** `$ICONNAME` и
  `LSMinimumSystemVersion`, **перед** `NSHumanReadableCopyright` — или
  после `NSHighResolutionCapable`, до `</dict>`. Порядок ключей в plist
  не важен для macOS, но логично держать `CFBundleDocumentTypes` рядом
  с `LSApplicationCategoryType`.
- Heredoc uses `<<PLIST` без кавычек — значит `$VAR` интерполируются.
  Внутри `CFBundleDocumentTypes` нет переменных, так что bash туда не
  полезет. Но проверить, что нет `$(…)` или backticks в XML-блоке.

### Шаг 5. Проверить, что drag&drop и ⌘O не сломались

`CFBundleDocumentTypes` объявляет, какие типы приложение принимает
**через систему** (Finder, `open`, Open With). Это **не заменяет** и **не
конфликтует** с drag&drop (`App.swift:202` `.onDrop(of: [.fileURL])`) и
⌘O (`Playlists.swift:134` `Chooser.folder`) — эти пути работают с
файлами напрямую, минуя систему типов. После правки drag&drop и ⌘O
должны работать как раньше.

## Что уже проверено (опорная база, не отменяет твоей проверки)

- `grep -n 'CFBundleDocumentTypes' .` по репо (исключая `docs/briefs/`) —
  пусто: ключа нет нигде, кроме этого брифа.
- `PlayerEngine.swift:77` — `formats = ["mp3", "m4a", "flac", "wav", "aiff", "aif"]`;
  `PlayerEngine.swift:82` — `kinds = "mp3, m4a, flac, wav and aiff"`.
- `build.sh:45` — `MINIMUM="14.0"`.
- `build.sh:102-122` — heredoc `cat > "$APP/Contents/Info.plist" <<PLIST`;
  внутри `<<PLIST` без кавычек, `$VAR` интерполируются.
- После merge SZ-01 (`e9abe1e8`) README/ROADMAP уже не заявляют «drag&drop
  only» — значит противоречия с новой защитой не возникает.

## Вне области

- **Не трогать ничего вне `build.sh`.** Особенно `Sources/`,
  `Tests/`, `Package.swift`, `README.md`, `README.ru.md`, `ROADMAP.md`,
  `VERSION`, `NOTES.md`, `CHANGELOG.md`, `.github/`, `Icon/`, `Installer/`,
  `media/`.
- **Не bump `VERSION`** — релизное решение владельца.
- **Не менять `MINIMUM`** — `14.0` остаётся; если flac требует 14.2,
  решается через `UTImportedTypeDeclarations`, а не bump'ом платформы.
- **Не пушить в `main`**, не трогать чужие ветки/репо.
- Не заводить issue по AUD-02 — координатор заведёт; эта волна работает
  от брифа, не от issue.
- Не переоценивать принятые волны P-03…P-10R, SZ-01.
- Не запускать `release.sh`/`tap.sh`.

## Definition of Done

- `build.sh:102-122` (heredoc) содержит `CFBundleDocumentTypes` с
  `LSItemContentTypes` для mp3, m4a, wav, aiff/aif, flac.
- Если flac требует `UTImportedTypeDeclarations` (вариант A) — блок
  добавлен и корректно объявляет flac с `conformsTo` = `public.audio`.
- `CFBundleTypeRole` = `Viewer`, `LSHandlerRank` = `Default`.
- После сборки: `plutil -p build/DajetPlayer.app/Contents/Info.plist`
  показывает `CFBundleDocumentTypes` с массивом типов; `plutil -lint`
  — plist валиден.
- `swift test` = 16/16 (код `Sources/`/`Tests/` не тронут, прогон —
  для уверенности).
- `./build.sh` собирается без warnings (кроме pre-existing `seek(to:)`
  deprecated в `PlayerEngine.swift:761` — это AUD-15, не этой волны).
- Drag&drop и ⌘O работают как раньше (локальный агент проверяет: бросить
  папку в окно — играет; ⌘O — открывает панель).
- **Ручная проверка на Mac** (локальный агент, после CI): двойной клик по
  `.mp3`/`.m4a`/`.flac`/`.wav`/`.aiff` в Finder → файл передаётся в
  DajetPlayer и играет. Это и есть приёмка AUD-02.
- PR открыт, база `main`, ревью SZ по verbatim-выводу + ручной проверки.
- `git diff --stat main..HEAD` — ровно один файл (`build.sh`).

## Форма сдачи

- ветка в префиксе `arena/` (имя на session-id, как для #13/#21), PR
  «build: declare CFBundleDocumentTypes for audio formats (AUD-02)»;
- тело PR: что сделано (вариант A или B для flac — явно), что не сделано,
  риски;
- в комментарии PR — verbatim-вывод:
  `git rev-parse HEAD` (база),
  `git diff --stat main..HEAD` (ровно build.sh),
  `plutil -p build/DajetPlayer.app/Contents/Info.plist` (показывает
  `CFBundleDocumentTypes`),
  `plutil -lint build/DajetPlayer.app/Contents/Info.plist` (OK),
  `swift test` (16/16, CI),
  `./build.sh` (финальная строка `built: …`);
- ручная проверка Mac (локальный агент): двойной клик по аудиофайлу в
  Finder → играет; drag&drop — работает; ⌘O — работает;
- ревью SZ — по этому выводу; merge — по слову владельца.

## Правила

- вопросы — до начала, через координатора;
- доказательство — `файл:строка` или команда с выводом; «кажется» не
  принимается;
- **выбор A/B для flac** — за Ареной, но с обязательной проверкой на
  целевой платформе (14.0 или 14.2+); если есть сомнения — спросить до
  кода, через координатора;
- `git status` чистый на выходе (только коммит в твою `arena/`-ветку);
- существующие контракты и принятые волны не переоценивать;
- если что-то в брифе не сходится с кодом по указанным строкам —
  остановиться и спросить, не додумывать.
