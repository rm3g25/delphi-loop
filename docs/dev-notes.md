# DelphiLoop — заметки разработки

Живой журнал рефакторинга под CODESTYLE 4.3: что сделано, зачем, и что решили
отложить. Обновляется каждую итерацию, приезжает внутри архива итерации.
Правки руками приветствуются — файл ездит туда-сюда через pack-src.bat.

---

## Процесс

- Помодульно, один модуль за итерацию, ревью после каждой.
- Архив итерации: `DelphiLoop-CODESTYLE43-NN.zip`, распаковка поверх корня
  репозитория. Внутри — полный рефакторинг одного модуля плюс минимальные
  патчи точек вызова, чтобы сборка оставалась зелёной.
- Обмен кодом: `tools\pack-src.bat` → `delphi-loop-src.zip` в корне.
  Белый список расширений; все `*.xml` исключены — в конфиге ключи.
- Пуш в гит один, в конце всего прохода.

## Порядок модулей

| # | Модуль | Статус |
|---|--------|--------|
| 02 | Engine.Types | готово |
| 03 | Engine.Consts | готово |
| 04 | Engine.Config | готово |
| 05 | Engine.Prompts | готово |
| 06 | Engine | готово |
| 07 | Syntax.DelphiLexer | готово |
| 08 | UI.Consts | готово |
| 09 | UI.CodeView | готово |
| 10 | зачистка ссылок на гайд | готово |
| 11a | UI.Main: шапка + TChatBubble | готово |
| 12 | гайд 4.5: шапки + Main.pas | готово |
| 13 | Main: Make*/Build*-методы | готово |
| 14 | Main: Chat*/Eng*/хендлеры | готово |
| 15 | пустые строки как пунктуация (4.6) | готово |

## Договорённости (зафиксировано до старта)

- **Только форма, не поведение.** Поведенческие находки копятся в копилке
  ниже и чинятся отдельным проходом после стилевого. Смешаешь — на ревью не
  поймёшь, что сломалось: стиль или логика.
- **Строковые значения протокола заморожены.** XML-теги (`'BaseURL'`,
  `'APIKey'`, `'ModelID'`, `'ExecutorIdx'`…), словарь тега Type
  (`'Ollama'/'OpenAI'/'Custom'`), маркер `NO_ISSUES`. Переименовываются
  только идентификаторы констант; старые конфиги обязаны грузиться.
- **inline var:** счётчики циклов — всегда `for var i`; inline-объявление —
  там, где переменная живёт внутри ветки или тела цикла; переменная на весь
  метод — в var-блоке сверху.
- **Сокращения разворачиваются:** `Idx` → `Index` в идентификаторах.
- **Хелперы в записях** — только когда есть две реальные точки использования,
  не впрок.
- **Имена типов не трогаем:** TLoopEngine, TLoopConfig, TLoopConfigIO.
- **UTF-8 BOM + CRLF** приводится попутно, в итерацию каждого модуля.
- **Мёртвый код не удаляется** в стилевом проходе — фиксируется в копилке.
- **Ссылки на CODESTYLE в рабочий код не вписываются.** Комментарий обязан
  быть самодостаточным; обоснования решений живут здесь, в dev-notes.
  С версии 4.4 это правило самого гайда (§8: «A comment explains the code,
  not how the code came to be») — вместе с запретом имён и «as agreed».
- **Гайд обновлён до 4.4** (§8 выше), затем **до 4.5**: запрет выровненных
  колонок распространён и на прозу в блочных комментариях — колонка ломается
  первой же длинной записью (Done/Error/Cost и сломала), а имена в таких
  списках — реальные идентификаторы, переименование рвёт вёрстку как в var.
  Формат: маркер и двоеточие. Разделители и ASCII-линейки — можно.
- **Гайд обновлён до 4.6:** пустая строка — граница фазы внутри метода, та же
  горизонтальная линия из §6, но ниже порога экстракции. Тест: **меняется ли
  субъект?** Не после begin, не перед end, не между каждой строкой, не между
  строками одного субъекта. Больше 4–5 групп — это сигнал экстракции, а не
  пунктуации.
- **Уточнение про inline var:** var-блок — для переменных, пронизывающих
  несколько фаз; переменная, рождающаяся первой строкой своей единственной
  фазы — inline, даже если доживает до end (как `Response` в примере §6). Решение о разделении UI.Main: юнит в
  стилевом проходе не режем (упрётся в отложенный §13 и смешает
  реструктуризацию с переименованиями); работу режем на 11a/11b/11c.
- **§13 гайда (формы в дизайнере vs UI в коде)** вынесен за скобки прохода.
  UI.Main построен целиком в коде; вероятно, это можно обосновать проектным
  исключением, но не в текущем виде. Решается отдельно, после прохода.

## Журнал итераций

### 02 — Engine.Types
- Переехал `TLoopSettings` из Engine.Config: Engine.Types = все пассивные
  записи движка. Типы событий и `TLoopPhase` остались в Engine — это
  контракт движка, а не общие данные.
- Поля: `BaseUrl`, `ApiKey`, `ModelId`, `ProviderIndex`, `ExecutorIndex`,
  `ReviewerIndex`. Патчи точек вызова: Engine, Engine.Config, UI.Main.
- Колонки убраны, BOM + CRLF, шапка юнита.

### 03 — Engine.Consts
- Все 43 константы SCREAMING_CASE → PascalCase одним проходом; значения
  байт-в-байт. Патчи: Engine, Engine.Config, Engine.Prompts, UI.Main.
- `APP_VERSION` в UI.Main намеренно не переименован: он там резолвится в
  UI.Consts (последний в uses побеждает), а не в Engine.Consts.
- Warning-комментарий у `DefaultExecutorIndex`/`DefaultReviewerIndex`:
  значения позиционные в список из SetDefaults.
- **Единственное намеренное изменение поведения за весь проход:** файл был
  без BOM, а в `PromptReviewer` живое тире. Без BOM компилятор на cp1251
  превращал его в `вЂ”` — ревьюер всё это время получал промпт с
  кракозяброй. С BOM строка компилируется честно.
- Заведён `tools\pack-src.bat`.

### 04 — Engine.Config
- Локальные константы `XML_*` → `Xml*`, `PROV_TYPE_*` → `ProviderType*`;
  значения заморожены.
- SetDefaults ужат ~130 → ~25 строк через приватные `AddDefaultProvider` /
  `AddDefaultModel` (§6, повторяющийся шаблон; §5 — методы, не вложенные
  процедуры: захватывают только поля).
- §12: interface uses — только Generics.Collections, Xml.XMLIntf,
  Engine.Types; SysUtils, Variants, Xml.XMLDoc, Engine.Consts уехали в
  implementation. System.Classes не использовался вовсе — удалён.
- Однобуквенные P/M/S/I → Provider/Model/Settings/`for var i`; inline var в
  телах циклов; гарды в две строки; TODO про DPAPI получил ссылку на
  roadmap. Патчей точек вызова нет — публичный контракт не менялся.

### 05 — Engine.Prompts
- `FILE_*` → `ExecutorPromptFile` / `ReviewerPromptFile` / `RefinePromptFile`;
  значения (имена md-файлов) заморожены — это пользовательский контракт из
  README.
- Тройной шаблон «загрузи файл, иначе дефолт» свёрнут в `GetPromptOrDefault`
  (§6); `LoadFromFile` переименован в `LoadPromptFile`.
- Отклонено: `TFile.ReadAllText` вместо TStringList — проще, но меняет байты
  промпта (нормализация переводов строк), а проход — только про форму.
- Колонки убраны, гарды в две строки, шапка юнита, BOM + CRLF.

### 06 — Engine
- Транспорт вынесен в свободные функции implementation-секции (§9):
  `PostJson`, `BuildOllamaRequest`, `BuildOpenAIRequest`, `ParseOllamaResponse`,
  `ParseOpenAIResponse`, `StripMarkdown`, `AskOllama`, `AskOpenAI` — ни одна не
  трогает состояние движка. Класс теперь = луп + события + диспетчеризация.
- Ask* стали конвейерами (§6): построй запрос → отправь → проверь код →
  распарси. Пирамида из четырёх вложенных try → nil-инициализация + один
  finally (§15, именованное исключение из §14) и guard-Exit.
- JSON запросов байт-в-байт прежний: порядок пар сохранён, каждый Create
  передаётся владельцу следующей строкой — окон утечки нет.
- §12: interface uses = Engine.Types + Engine.Config, остальное вниз;
  System.Generics.Collections не использовался — удалён.
- Параметры: `AMsg` → `AMessage`, `MaxIter` → `MaxIterations`,
  `ABaseURL/AAPIKey/AModelID` → `ABaseUrl/AApiKey/AModelId`,
  `A*Idx` → `A*Index`. Имена параметров в типах событий на совместимость
  method pointers не влияют — UI.Main не тронут.
- **Микро-изменение поведения №2 (в плюс):** пустой ключ больше не шлёт
  заголовок `Authorization: Bearer ` с пустым значением — заголовок просто
  не ставится. Для api.openai.com разницы нет (401 и так, и так), для
  локальных OpenAI-совместимых без авторизации запрос стал чище.
- Кракозябра в статусе «Max iterations reached — …» починена BOM-ом
  (предсказано в заметках, свершилось).

### 07 — Syntax.DelphiLexer (+ хотфикс Engine)
- **Хотфикс Engine.pas (H2443):** System.Generics.Collections вернулся в
  implementation uses — он нужен для inline-экспансии `TJSONValue.GetValue<T>`,
  хотя ни один его символ в коде не упоминается. Помечен комментарием
  «do not clean up» по образцу link-only юнитов из §12. Урок: юниты для
  inline-дженериков RTL grep-ом по символам не видны.
- Классификаторы символов (`IsIdentStart/IsIdentPart/IsDigit`) и `MakeToken`
  → свободные функции (§9): состояние лексера им не нужно.
- Пятичленное условие двухсимвольных операторов → `IsTwoCharOperator` (§3:
  три и более термов — кандидат на именованную функцию).
- Tokenize остался единой диспетчер-простынёй — §6 прямо разрешает: один
  проход, одна фаза. Var-блок исчез: `Ch`, `Text`, `Kind` теперь inline.
- `KW` → `Keywords`, `W`/`C`/`N`/`P` → нормальные имена; SysUtils уехал в
  implementation; двойные пробелы и выравнивание убраны.
- Тела всех Read* не тронуты байт-в-байт (сверено счётчиками
  Advance/Copy/CharInSet/Break) — парсер не рефакторят на глаз.

### 08 — UI.Consts
- Все ~95 констант SCREAMING → PascalCase, значения байт-в-байт (глифы,
  форматные строки, цвета). Сокращения развёрнуты: `BG` → Background,
  `BDR` → Border, `HDR` → Header, `NOISS` → NoIssues и т.д. T-shirt шкала
  шрифтов оставлена шкалой: FontXs/FontSm/FontMd/FontLg.
- Строковые константы UI переведены на RTL-конвенцию S-префикса
  (`SReady`, `SIterationFormat`) — как в примерах самого гайда
  (SMissingApiKey). Прямое `Str*`/`Text*` отвергнуто: `TextSettings`
  столкнулся бы с одноимённым свойством FMX.
- **Копилка №5 полуразминирована бесплатно:** `APP_VERSION` в UI.Consts стал
  `AppVersionLabel` ('v0.3', отображаемая метка) — коллизия с
  `AppVersion` из Engine.Consts ('0.3', версия протокола) исчезла на
  уровне имён. Поведение не менялось.
- resourcestring для UI-строк отвергнут сознательно: локализации нет в
  планах, а глифы-иконки переводу не подлежат — семья констант осталась
  единой.
- Надгробный комментарий «removed in v0.3» удалён — история живёт в git.
- Файл получил CRLF (был LF в рабочей копии) — минус один из трёх.
- Патч UI.Main: ~200 механических переименований. CodeView UI.Consts не
  использует — не тронут.

### 09 — UI.CodeView
- Константы `CCLR_*`/`CV_*` → `CodeColor*`/`Code*` (CodeColorBackground,
  CodePaddingVertical, CodeLineHeightEstimate…); значения байт-в-байт.
  Патч UI.Main — четыре строки в ChatAddCode.
- `ColorForKind` и `CountLines` → свободные функции (§9): карта цветов и
  подсчёт строк состояния контрола не трогают. `CountLines` берёт текст
  параметром.
- Дубль установки шрифта (MeasureFont + Paint) свёрнут в `ApplyCodeFont`;
  строка 'Cascadia Code' из двух литералов стала константой
  `CodeFontFamily` (§7: literal used more than once).
- §12: interface uses ужат до Classes / Generics.Collections / FMX.Controls /
  Syntax.DelphiLexer; Types, UITypes, FMX.Types, FMX.Graphics — вниз.
  **System.SysUtils и System.Threading удалены совсем** (ни одного символа;
  TThread.ForceQueue живёт в System.Classes). После урока H2443 — под
  проверку компилятором.
- Paint: `X/Y/TW/R/ColPos/NextTab/C/I` → `CursorX/CursorY/TokenWidth/
  TokenRect/Column/NextTabStop/Ch/i`, inline var в теле цикла; var-блок
  метода — только CursorX/CursorY, живущие весь проход. Математика
  табуляции и метрик не тронута ни на символ.
- Анонимный ForceQueue с отложенным UpdateHeight сохранён как есть —
  выстраданное правило «не мутируй layout внутри Paint» сильнее красоты.

### 10 — зачистка ссылок на гайд
- Итерации 07–09 приняты: всё компилируется и запускается.
- Из пяти комментариев убраны хвосты «(guide, N)» — Engine, Engine.Config,
  Syntax.DelphiLexer, UI.CodeView. Содержательная часть комментариев
  осталась: «free functions, no state involved», «broad catch is
  deliberate», «do not clean up» — они самодостаточны и без номера параграфа.

### 11a — UI.Main: шапка + TChatBubble
- Глобальные переименования по всему файлу (сборка зелёная, зоны 11b/11c
  дальше правятся без переименований): поля `FCboExec`→`FComboExecutor`,
  `FEdtORKey`→`FEditOpenRouterKey`, `FThinkBuf`→`FThinkBuffer` и ещё ~15;
  методы `Mk*`→`Make*`, `ChatAddIterHeader`→`ChatAddIterationHeader`,
  `On*Btn*`→`On*Button*`; параметры `ATxt/ASz/AW/AH/AVal/AMsg/AIter/AMax/
  AExec/ARev/AChars` → полные имена.
- Шапка юнита: сняты пины «v0.3», починена строка про OnDone (панели
  результата больше нет — есть пузырь в ленте), ASCII-дефисы.
- §12: {$IFDEF MSWINDOWS}-блок (WinApi, DwmApi, FMX.Platform.Win) и ещё
  11 юнитов уехали в implementation; interface uses ужат до 15 → нужного
  для объявлений минимума (SysUtils остался: TStringBuilder — поле).
- TChatBubble: поля public намеренно (OnCodeViewResized правит их снаружи)
  — задокументировано комментарием; двойной `public` слит;
  `FCollH/FExpandH/FChevronLbl` → полные имена; `OldH/NewH` →
  `OldHeight/NewHeight`, `Delta` растворён в вызове.
- Объявление TfrmMain: колонки убраны, двойные пробелы после
  function/procedure убраны, переносы — на один уровень.

### 12 — гайд 4.5: развыравнивание шапок + Main.pas
- 11a принята: всё скомпилировалось.
- Все табличные шапки переведены на «маркер и двоеточие»: Main (Output +
  Engine event contract), Engine (event contract), Syntax.DelphiLexer
  (token kinds), Engine.Consts (таблица цен в //), UI.CodeView (пример
  Usage — убраны выровненные :=, Contract — отступ маркеров).
- **UI.Main.pas → Main.pas, unit Main.** Форма — не часть переиспользуемой
  подсистемы UI из src, она и есть приложение; имя UI.Main клялось в чужой
  принадлежности. Один юнит в приложении — неймспейс не нужен; появятся
  соседи — станут App.*.
- dpr: ссылка обновлена, список сгруппирован App → Engine → Syntax → UI
  (Engine.Prompts больше не прячется в хвосте). dproj: DCCReference
  обновлён.
- Старый apps/DelphiLoop/UI.Main.pas удаляется руками (zip поверх корня
  файлы не удаляет).

### 13 — Main: Make*/Build*-зона
- 12 принята (компилируется; замечание про хвостовые нарушения — они в
  зонах 13/14, до которых руки как раз и дошли).
- **13 вложенных процедур повышены до приватных методов** (§5: ни одна не
  захватывает локалы родителя — только поля и параметры): BuildLogoRow,
  BuildStatusBlock, BuildSidebarFooter (бывш. BuildSettingsFooter — имя
  освобождено для футера оверлея), BuildChatArea, BuildInputArea,
  BuildInputMemo, BuildInputFooter, BuildSettingsHeader/Body/Footer,
  AddSettingsSectionLabel/Card/Row. Тела-хозяева стали оглавлениями.
- FMX.ScrollBox поднят в interface uses (TScrollBox теперь в сигнатурах).
- Выравнивание `:=` и `Имя :Тип` снято по всему файлу (глобально — зона 14
  дальше правится без этого шума); однобуквенные и Lbl*/Lay*/Rect*-локалы
  зоны → полные имена; `L/S/P/I` → SectionLabel/Settings/Provider/`for var i`;
  LblDesc → inline var в ветке.
- Однострочные if в MakeRect → гард-форма; комментарий «history v0.4» →
  честный TODO со ссылкой на roadmap.

### 14 — Main: Chat*/Eng*/хендлеры (финал прохода)
- 13 принята (компилируется, запускается, «читать приятнее»).
- Локалы хвоста → полные имена: `HeaderLay/ChevronLbl/BodyLbl/CopyBtn/…` →
  `*Layout/*Label/*Button`; `CollH/ExpandH/EstCodeH/BubbleW` → `*Height/*Width`;
  `ExecIdx/RevIdx/MaxIter` → полные; `CV/CB/Svc/Ctrl/Obj/P` →
  `CodeView/ContentRect/ClipboardService/Item/Item/ParenPos`. Безымянные `Lbl`
  получили имена по роли в каждом методе (HeaderLabel, ThinkingLabel,
  DoneLabel, ErrorLabel, CostLabel, ButtonLabel — хвост 13-й зоны).
- Однострочные `if X then Exit;` → гард-форма по всему файлу; выравнивание
  веток case в EngPhase снято; циклы RecalcBubblesFrom/ChatClear —
  `for var i` / `for var Item in`, var-блоки ужаты.
- Сырые тире и стрелки в комментариях → ASCII (в строках остались
  #$2014/#$2192-эскейпы — это значения, не тронуты).
- Выстраданные комментарии сохранены дословно: про TagString на внутренней
  метке, про Height=0 при Align=Top, про отказ от ChatScrollToBottom в
  OnCodeViewResized.
- Строки >100 колонок: ноль во всём файле.

## Итог стилевого прохода (02–14)

Весь код приведён к CODESTYLE 4.5: девять модулей src + приложение
(Main.pas, dpr, dproj). Сборка оставалась зелёной после каждой итерации.
Поведение не менялось, кроме двух задокументированных микро-исправлений
в плюс: BOM починил кракозябры в промпте ревьюера и статусе движка;
пустой ключ больше не шлёт пустой Bearer-заголовок.

Дальше, отдельными проходами:
1. **Пуш** — паттерн двух коммитов: `refactor: apply CODESTYLE 4.5` (весь
   код) + `chore: dev-notes, dpr regroup` — затем `git add --renormalize .`.
2. **Поведенческий проход по копилке** — 17 пунктов, чинить по одному
   коммиту на пункт.
3. **Архитектурный проход** — §13 (дизайнер vs код), судьба UI.Consts,
   Chat*-семейство просится на общий хелпер шапки пузыря. Кандидаты по
   §6 (больше 5 фаз в теле): ChatAddResult (16), Tokenize (14), ChatAddTask
   (13), RunLoop (12), ChatAddCode и ChatAddReview (11), Paint (11).

### 15 — пустые строки как пунктуация (CODESTYLE 4.6)
- 30 границ фраз по трём файлам. Тест «меняется ли субъект» применялся
  точечно: методы-однофразники (Do*-диспетчеры движка, Make*-конструкторы,
  короткие Read* лексера, ColorForKind) не тронуты — воздух везде есть
  воздух нигде.
- Engine (7): PostJson — сборка клиента / отправка; BuildOllamaRequest и
  BuildOpenAIRequest — наполнение / сериализация; ParseOpenAIResponse —
  контент / счётчики токенов; StripMarkdown — открывающие ограждения /
  закрывающее / финальный Trim; AskModel — резолв провайдера / диспетчер;
  Run — сохранение настройки / запуск задачи.
- Syntax.DelphiLexer (3): ReadNumber — целая часть / дробная / экспонента;
  ReadOperator — чтение символов / решение.
- Main (20): ChatAddIterationHeader и ChatAddThinkingText — построение
  метки / бухгалтерия ленты (пример из самого гайда); MakeBubble,
  RecalcBubblesFrom, ChatClear, FillCombos, SyncConfigToUI, SyncUIToConfig,
  EngThink, EngReview, SetRunning, OnMemoChange, OnResetClick,
  OnSettingsBackClick, BuildInputMemo.
- **`Anim` в OnSettingsBackClick → inline var**, var-блок метода исчез:
  переменная рождается первой строкой своей единственной фазы.
- Проверка: ни одной пустой строки после begin или перед end; методы с
  6+ группами — только длинные Chat*/Build*-строители, RunLoop, Tokenize и
  Paint (кандидаты §6 на экстракцию, записаны в архитектурный проход).

## Копилка: к исправлению после стилевого прохода

Поведенческие болячки. Найдены по ходу, не тронуты сознательно.

1. **Позиционная связь моделей и провайдеров.** `TModelConfig.ProviderIndex`
   — индекс в список; `RemoveProvider` индексы в моделях не чинит: удаление
   провайдера молча перевешивает модели на чужие или несуществующие.
2. **`ErrorHttpPrefix + код` как возвращаемое значение** AskOllama/AskOpenAI
   вместо исключения. Вызывающий не отличит сетевую ошибку от кода, честно
   начинающегося со слова Error (§15).
3. **Дублированный маппинг `TProviderType` ↔ строка** в SaveProviders и
   LoadProviders — просится пара функций.
4. **`ptCustom` и `ptOpenAI` в AskModel — одна ветка.** Enum обещает три
   поведения, реализовано два.
5. **Двойной `APP_VERSION`:** Engine.Consts `'0.3'` и UI.Consts `'v0.3'`.
   Кто победит в UI.Main — решает порядок uses.
6. **UI.Main:1663 повторно парсит `NO_ISSUES` из строки** (и без UpperCase,
   в отличие от движка), хотя `AApproved` уже приехал в событии. Нарушение
   собственного контракта v0.3, два места решают один вопрос по-разному.
7. **Стоимость токенов всегда по тарифу gpt-4o:** `CostPerTokenGpt4o`
   захардкожен в RunLoop; счётчик врёт для всех остальных моделей.
8. **Мёртвые константы:** AppTitle, ProviderOpenAIKey, ProviderOpenRouterKey,
   CostFormat, CostPrefix, CostPerTokenGpt4oMini.
9. **`case Provider.Kind of` в SaveProviders без else:** при четвёртом
   значении enum в XML утечёт Kind из прошлой итерации цикла.
10. **Две философии ошибок в TLoopConfig:** тихий Exit в Remove*/Update* на
    кривом индексе против громкого ERangeError в Get*. §15 просит выбрать
    одну.
11. **Trim в LoadPromptFile съедает завершающий перевод строки.** Встроенные
    промпты кончаются `#10`, внешние — обрезаются. В Engine промпт клеится с
    кодом (`GetReviewerPrompt + Code`), и с внешним файлом выходит
    `Code:<код>` без переноса — уже сейчас: `assets/prompt_reviewer.md`
    кончается на `Code:` без newline. Встроенный и внешний промпт дают модели
    разный вход.
12. **Повторный Run не защищён.** FMaxIterations/FProviders/FModels пишутся из
    UI-потока, читаются из фонового; второй Run во время работы = два
    параллельных лупа на общих полях. UI прикрывает кнопкой, движок — нет.
13. **Токены Ollama не считаются**, хотя API отдаёт `eval_count` и
    `prompt_eval_count` — для локальных моделей счётчик всегда 0.
14. *(минорное)* Экранированные идентификаторы вида `&end` лексер красит как
    оператор `&` + keyword `end` — в валидном коде это единый идентификатор.
15. **Десять мёртвых констант в UI.Consts:** ColorAccentLight,
    ColorThinkBackground («legacy - kept for reference» — эталонное литтер-
    оправдание), ColorReviewFix, ColorTaskBorder, ColorReviewRejectBorder,
    ColorReviewNoIssuesBorder, ColorResultHeader, ColorBadgeFix,
    SeparatorHeight, SReviewRejected. Плюс дубль: SButtonRun и
    SButtonRunIcon — одинаковый глиф #$25B6 под двумя именами.
16. **SetCode: `FTokens.Free` перед переприсвоением** — если Tokenize упадёт,
    поле останется висячим указателем на освобождённый список, и следующий
    Paint словит use-after-free. §14 велит здесь FreeAndNil
    (teardown-and-rebuild) — отложено как поведенческая правка.
17. **Тройка захардкоженных «3»** расходится с DefaultMaxIterations = 4:
    `FMaxIterations := 3` в Create, `FProgressRun.Max := 3`,
    `FSpinIterations.Value := 3`. SyncConfigToUI перекрывает, но до первого
    Sync движок и виджеты живут с чужим дефолтом.

## Заметки на будущее

- **DelphiLoop.dpr:** все src-юниты в списке есть (Engine.Prompts — последней
  строкой, IDE дописывает в хвост). В итерацию 10 сгруппировать список по
  подсистемам, чтобы глаз не терял хвостовые юниты.

- **LF в рабочей копии** у Syntax.DelphiLexer, UI.CodeView, UI.Consts —
  наследие догитатрибутного чекаута. Вылечатся в свои итерации (07–09),
  руками не трогать.
- ~~Engine.pas: кракозябра в статусе «Max iterations reached»~~ — починено
  в итерации 06.
- **`DoCode(Code, 0, True)`** — булев литерал на вызове (§6 про читаемость
  call-site). Лечится enum-ом в сигнатуре `TOnCodeEvent`, но это правка
  публичного контракта — решать вместе с UI.Main в итерации 10.
- **UI.Consts — палитра и строки DelphiLoop, а не универсальные UI-токены**;
  второе приложение её как есть не возьмёт. Кандидат на переезд/переименование
  в архитектурном проходе вместе с §13.
- После прохода: обновить README (описания юнитов, имя Main.pas), решить
  судьбу §13, пройтись по копилке отдельными коммитами.
