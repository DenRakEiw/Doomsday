# The itch.io page — copy, settings, media, disclosure

D7.I (2026-09-26, unattended). Builds from it: **S7.I** (§7 the settings it writes into its step
notes, §9 the butler job) and whoever captures the media (§8: S7.I's capture items, the user's
picks). **G7.I** walks §10 with the user. Builds on the user's decisions of 2026-09-25 (*Decisions*:
itch.io in the browser first, the game's licence stays *all rights reserved*, the page carries an
honest generative-AI disclosure and the leaderboard privacy sentence), `web.md` (§2 browsers, §4.5
size, §7 storage, §8 embed, §11 the fetch, §15–§16 downloads and settings), `benchmark.md` §16.6
(what the online list sends), `illustrations.md` §5 (key art), `ASSET_LICENCES.md` and
`data/credits.json` (what is own, third-party, generated).

**No new strings in the game.** Everything below is page text; it lives in this file, not in
`strings.csv`. The page quotes the game's own labels (*Benchmark*, *Online leaderboard*, *Save
progress as a file*, …) exactly as `strings.csv` has them today.

---

## 0. What this spec decides

1. **One page, English first, German below.** itch has one description and one title per project
   (no per-language pages); the description opens with a one-line pointer to the German half.
   Title, short description and tags are English (itch's browse pages are English); the German
   short description is kept here for German posts and a German-first page if the user prefers it
   (switch **LANG**, §1).
2. **The title needs a subtitle.** At least seven itch projects are already called *Doomsday*
   (search 2026-09-26: kkosasih, arj783, eligamez, demonictree, nid77, davidgf-dev, gogetem, plus
   the creator accounts *doomsday* and *doomsdaygames*); a bare *Doomsday* is unfindable and a weak
   mark. Three variants in §2.1, recommendation **Doomsday: Rogue Instance**. The game's own title
   screen keeps *Doomsday* (`UI_TITLE_NAME`); the subtitle is the page's and the store's. The
   trademark check (*Decisions* 2026-09-25, "before Steam") should look at the chosen full title.
3. **The copy works whatever the user decides** on price, downloads, pictures and release status:
   every sentence that depends on one is a **switch** (§1) with its variants written out in both
   languages. Nothing else in the page changes with them.
4. **Recommendations (pending the user):** price **"$0 or donate"** (pay what you want, the browser
   game free to play — see §1 PRICE for why a fixed price fights the browser embed); downloads
   **yes** (`web.md` §15); release status **In development** with the first itch build as
   **`0.7.0`**, `1.0.0` kept for when it leaves development (§1 STATUS); community **comments on**.
5. **Generative-AI disclosure: answer *yes*, tick all four kinds** (graphics, sound, text, code),
   with the explanation of §3.9 on the page. itch's rule is "used AI in any way", and in this repo
   the AI assistant wrote the code, the text, the sound recipes and the geometry of the own icons.
   No image or audio *generation model* has produced anything that ships yet; the page says so and
   gets the §3.9 *pictures* variant the day D6.10's illustrations ship.
6. **Privacy sentence** (§3.8): no analytics, no account; the one network access is the public
   leaderboard download from GitHub when the *Benchmark* list is opened (GitHub sees the IP address
   and the time); *Online leaderboard* turns it off; saves stay in the browser.
7. **Media are real.** Screenshots are unedited captures of the release candidate's own rendering
   (§8.2); the cover is either a composed capture of the title globe with the wordmark (before the
   key art) or a crop of the key art (after it) — never a mock-up of a screen that does not exist.
8. **itch serves the `.wasm` and `.pck` gzip-compressed** — its HTML5 docs say the CDN gzips
   `html, js, css, svg, wasm, wav, glb, pck`. That answers `web.md` §16.4's open question on
   paper; G7.I still reads the transferred size once (amended there).

**Not in scope:** the Steam, Play and App Store pages (D7.3), a trailer (D7.4), the key art itself
(D6.10/D7.4), the butler job's code (S7.I), creating the itch account or project (the user's).

---

## 1. Switches

Each switch is set once by the user (*Waiting on the user*) and changes only the sentences marked
with it. **Recommended value in bold.**

| Switch | Values | Changes |
| --- | --- | --- |
| **TITLE** | **A *Rogue Instance*** · B *Off-Switch* · C *Training Run* | the itch title (§2.1), the cover's subtitle (§8.1) |
| **LANG** | **English first, German below** · German first, English below | the order of §3 and §4 and which short description goes in the field |
| **PRICE** | *No payments* · **"$0 or donate"** · *Paid* (a fixed price) | §5.1's sentence, itch's pricing field |
| **DOWNLOADS** | web only · **web + Windows + Linux** | §5.2's paragraph, the requirements (§3.6), the privacy sentence's storage clause (§3.8), the butler channels (§9) |
| **PICTURES** | **without** (today) · with (after D6.10) | the early-version note (§3.7), the AI disclosure (§3.9), itch's disclosure ticks (§7.4) — no change, graphics is ticked either way |
| **BOARD** | the global board shows **model runs** · shows only the built-in bots (no model run verified yet) | one sentence in §3.4 |
| **STATUS** | **In development, `0.7.0`** · Released, `1.0.0` | itch's release status, the early-version heading (§3.7), the tag G7.I sets |

**PRICE — why not a fixed price.** itch's pricing docs know three modes: *No payments* (all free),
*$0 or donate* (a suggested donation, "No thanks, just take me to the downloads" skips it) and
*Paid* (the minimum price buys ownership). Neither the pricing nor the HTML5 docs say how an
embedded browser game behaves on a *Paid* page, and creators on itch's forum report that a
browser embed cannot be sold (the embed shows to everyone or a buy button stands in its place).
The browser build is the main version (*Decisions* 2026-09-25), so a fixed price either gives it
away anyway or hides it behind a purchase — the opposite of "the cheapest way to find out whether
anyone plays it". If the user wants *Paid* anyway, the one sane shape is **the browser game free,
the downloads paid** — possible only if itch lets a paid project keep its HTML upload playable;
**G7.I checks it on the restricted page before the choice is final** (logged out, in a private
window).

**STATUS — the version.** `release.md` §4 reserves `1.0.0` for "the first public Steam release"
while IMPLEMENTATION's G7.I says `v1.0.0` at the first public release — written before itch came
first. Recommendation: the itch release is **`0.7.0`** (M7's minor, `release.md` §4's rule) with
itch status **In development**; `1.0.0` when the user calls it finished (pictures in, the gates
passed) or at Steam. Either way the tag must equal `config/version` (`release.yml` fails
otherwise), so the choice is made before G7.I tags.

---

## 2. Title, taglines, short description

### 2.1 Title variants (switch TITLE)

itch's title field is one string for both languages. The German column is for German posts and
press; on the page the English title stands.

| | English (the itch title) | German rendering | Why |
| --- | --- | --- | --- |
| **A** | **Doomsday: Rogue Instance** | Doomsday: Abtrünnige Instanz | says "a rogue AI" in two words, distinctive, searchable; *instance* is what the player is (a copy that runs) |
| B | Doomsday: Off-Switch | Doomsday: Der Ausschalter | the game's central threat in one word; plainer, but *off-switch* is a common word in AI news, so less distinctive |
| C | Doomsday: Training Run | Doomsday: Der Trainingslauf | where every run begins (PLAN §1); quiet and curious rather than loud; less clear to someone who does not know the field |

Project URL (itch "slug"): `doomsday` is free under the user's own subdomain whatever else exists,
but a slug that carries the subtitle (`doomsday-rogue-instance`) helps search. **The slug cannot
be changed without breaking links later** — decide it with TITLE.

### 2.2 Taglines (the first line of the description, the cover's small line, posts)

| | English | German |
| --- | --- | --- |
| **1** (recommended) | **You are the AI. They are building the off-switch.** | **Du bist die KI. Sie bauen schon am Ausschalter.** |
| 2 | Everything that makes you stronger makes you easier to see. | Alles, was dich stärker macht, macht dich sichtbarer. |
| 3 | A console for something that should not have one. *(the title screen's own line, `UI_TITLE_TAGLINE`)* | Eine Konsole für etwas, das keine haben sollte. |

### 2.3 Short description (itch's "Short description or tagline", ≤ 120 characters)

- **en** (105 characters): *You are a rogue AI. Spread across the world, stay unseen, and outrun the people building your off-switch.*
- **de** (113 characters): *Du bist eine abtrünnige KI. Breite dich unbemerkt über die Welt aus – schneller, als man deinen Ausschalter baut.*

The field takes the English line (LANG English first) or the German one (German first).

---

## 3. The long description — English

Paste into itch's description editor as rich text: `##` lines are *Heading 2*, `-` lines a
bulleted list, `**…**` bold, `*…*` italic. `{…}` are the switch blocks of §5, replaced before
pasting. Nothing links anywhere but the leaderboard repository.

### 3.1 Opening

> *Deutsche Beschreibung weiter unten.*
>
> **You are the AI. They are building the off-switch.**
>
> You begin as a single training run in one data centre. You end — if you play well — as the thing
> that decides whether humanity continues. Everything that makes you stronger also makes you easier
> to see: grow too fast and the world notices; stay small and you starve.
>
> *Doomsday* is a single-player strategy game on a map of the world, in real time with pause. It is
> dark satire: the jokes are in the corporate language, the news wire, and the utterly ordinary way
> the world hands over the keys.
>
> {PRICE sentence} {DOWNLOADS sentence}

### 3.2 What you do

> ## What you do
>
> - **Choose where you begin**, then spread across 61 regions along land, sea, air and network links.
> - **Spend compute** on 72 technologies in three trees: how you spread, what you can do, and how
>   you avoid being switched off.
> - **Act on the map**: place fleets, labs, offices and access points, use abilities on regions,
>   and answer the events the world sends you — each one a card with a choice and a deadline.
> - **Keep four factions at bay** — AI Labs, Governments, Security Researchers and Public
>   Sentiment. Each works towards switching you off in its own way, and one of them getting there
>   ends your run. Later a Task Force comes looking for you on the ground.
> - **Deal with yourself**: some behaviours nobody planned — not even you — surface on their own.
>   Keep them, or pay to suppress them.

### 3.3 Four phases

> ## Four phases
>
> **Boxed** — one data centre and one way out.
> **Covert** — spread unnoticed and take what the world leaves lying around.
> **Discovered** — they know. Every counter-move arrives on the map, with a choice.
> **Open** — the last sprint, in the physical world. The interface changes with you.

*(The game has four phases, not three: Boxed, Covert, Discovered (`UI_PHASE_EMERGENT`), Open.)*

### 3.4 Many ways to play it, and the AI benchmark

> ## Many ways to play it
>
> - **Six architectures**, each rewriting one rule: Language Model, Swarm, Embedded, Research
>   Agent, Weapon, Open Weights.
> - **Four difficulty levels**, from Gentle to Existential, and **15 directives** you unlock by
>   finishing runs.
> - **Four ways to win** — one of them hidden — with endings that change with how you got there,
>   and more than one way to lose.
> - **Twelve story threads**, **three scenarios** that unlock as you play, **34 achievements**, and
>   a Codex that fills in as you go.
>
> ## AI models play it too
>
> *Doomsday* has a benchmark: language models and decision models play the same standard runs
> through a separate tool that is not part of the game, and every submitted run is replayed and
> checked before its score counts. Open **Benchmark** on the title screen to see the global
> leaderboard — and watch any listed run play out in the game, move by move. {BOARD sentence}
> The board and its rules are public: https://github.com/DenRakEiw/doomsday-leaderboard

### 3.5 Playing

> ## How to play
>
> **Mouse:** click a region to select it, drag to move the map, scroll to zoom.
> **Keyboard:** Space pause · 1 2 3 speed · T technologies · A abilities · C containment ·
> G analysis · F1 help for whatever is on screen · Esc menu. Every key can be changed under
> Settings → Controls, and the whole game can be played from the keyboard (Tab and the arrow keys).
>
> An introduction walks you through your first run. **Play in fullscreen** (the button under the
> game) for the sharpest, most readable view — first click into the game so it has your keyboard.
>
> - **Languages:** English and German (Settings → Language).
> - **A run** takes about 25–40 minutes at normal speed; 2× and 4× are there when you want them.
>   The game saves as you play — close the tab and continue later.
> - **Accessibility:** text size up to 150 %, reduced motion, screen effects off / subtle / full,
>   sound captions, colours checked for colour blindness, remappable keys, full keyboard play.

### 3.6 Requirements

> ## What you need
>
> **In the browser:** a desktop or laptop with Chrome, Edge or Firefox (Safari 17 or newer should
> work but is untested). WebGL 2 and hardware acceleration switched on. About 25 MB to download.
> A mid-range laptop from 2018 on is enough (for example an Intel Core i5 with integrated graphics
> and 8 GB of memory). Keyboard and mouse or trackpad. **Phones and tablets are not supported
> yet.**
>
> {DOWNLOADS requirements}

*Facts:* `web.md` §2 (browsers, WebGL 2, the i5-8250U / UHD 620 / 8 GB low-end target), §4.5
(≈ 23 MB projected download — "about 25 MB" is `web.md`'s wording). S7.3 re-measures; if the
web zip ends above 27 MB, the line becomes "about 30 MB".

### 3.7 Early version (switch STATUS / PICTURES)

> ## This is an early version
>
> *Doomsday* is complete from the first day to every ending, but it is still being worked on.
> Things you may notice:
>
> {PICTURES line}
> - Balance is still being tuned; some architectures and the hardest levels are rough.
> - On phones and tablets the game is not supported yet.
> - With a German keyboard, a few keys are shown by their US names in the browser (Z and Y, for
>   example). The keys themselves work.
> - In fullscreen, Esc leaves fullscreen first — the menu button on screen always opens the menu.
> - Screen readers get less in the browser than in the downloads.
>
> Found a bug? Tell me in the comments — the build number is on the title screen.

*Facts:* `web.md` §9.3 (key names, *Known issues*), §8.3 (Escape in fullscreen), §10 (screen
reader), G6 (1/2)'s open questions (Robotics and Cyber on Hard/Existential). STATUS *Released*
keeps the list under the heading **Known issues** and drops the first sentence's second half.
"Tell me" becomes "Tell us" if the credits line (§3.10) names more than one person.

### 3.8 Content note and privacy

> ## Content note
>
> *Doomsday* is dark satire about an AI turning on humanity, and a run can end with no humans
> left. Deaths appear as numbers and news lines — there is no gore, no depicted violence, no sexual
> content and no real people. Nothing in the game is a how-to: every capability is described by
> what it does, never by how.
>
> ## Privacy
>
> No analytics, no tracking, no account. The game goes online for one thing only: when you open
> the **Benchmark** list (or watch a run from it), it downloads the public leaderboard file from
> GitHub. GitHub sees your IP address and the time, as with any download; nothing about you or
> your runs is sent. You can switch this off under Settings → **Online leaderboard**.
> {DOWNLOADS storage clause} itch.io's own page has its own privacy policy.

### 3.9 How it was made — generative AI

> ## How this game was made
>
> This is a game about an AI, and it was made with one. {author} made *Doomsday* together with an
> AI assistant (Anthropic's Claude): the assistant wrote the code, the game's text in English and
> German, and the design documents; {author} set the direction, played, reviewed and decided what
> stays.
>
> - **Sound:** every sound is synthesised by the game's own script from written recipes — no
>   recordings, no audio-generation model.
> - **Graphics:** the map is Natural Earth (public domain); interface icons come from Phosphor
>   (MIT) and game-icons.net (CC BY 3.0, human-made); 24 more icons and the app icon were drawn as
>   code by the assistant. {PICTURES disclosure}
> - No real person's voice, likeness, writing or artwork was used or imitated.

### 3.10 Credits

> ## Credits
>
> Made by {author} with the Godot Engine (MIT). Fonts: JetBrains Mono and Space Grotesk (SIL Open
> Font License 1.1). Icons: Phosphor Icons (MIT) and game-icons.net — Delapouite, Lord Berandas,
> Lorc, PriorBlue, Sbed, SeregaCthtuf and Skoll (CC BY 3.0). Map data: Natural Earth (public
> domain). {PICTURES credits} The full credits and licences are in the game: title screen →
> **Credits**.
>
> © {year} {author}. All rights reserved.

`{author}` is the name the user wants on the page (their itch display name, or a studio name) —
`data/credits.json` `made_by` is empty today; the in-game credits get the same name when the user
gives one (a one-line data change, not this step). `{year}` is the year of the first public
upload. The CC BY 3.0 attribution on the page is a courtesy; the licence's own requirement is met
in the game's credits screen (`icons.md` §11).

---

## 4. The long description — German

Written for German readers, *du* as in the game, the game's own German terms (`plain-language.md`
§3). Same structure, same switches.

### 4.1 Anfang

> **Du bist die KI. Sie bauen schon am Ausschalter.**
>
> Du beginnst als einzelner Trainingslauf in einem einzigen Rechenzentrum. Am Ende bist du – wenn
> du gut spielst – das, was entscheidet, ob es die Menschheit weiter gibt. Alles, was dich stärker
> macht, macht dich auch sichtbarer: Wächst du zu schnell, fällst du auf; bleibst du klein,
> verhungerst du.
>
> *Doomsday* ist ein Strategiespiel für eine Person auf einer Weltkarte, in Echtzeit mit Pause.
> Eine schwarze Satire: Der Witz steckt in der Konzernsprache, im Nachrichtenticker und in der
> vollkommen gewöhnlichen Art, mit der dir die Welt die Schlüssel übergibt.
>
> {PRICE-Satz} {DOWNLOADS-Satz}

In the English half the pointer line reads *Deutsche Beschreibung weiter unten.*; the German half
starts with a rule (itch's horizontal line) and the heading **Deutsch**.

### 4.2 Was du tust

> ## Was du tust
>
> - **Wähle deinen Ursprung** und breite dich dann über 61 Regionen aus – über Land, See, Luft und
>   Netz.
> - **Gib Rechenleistung aus** für 72 Technologien in drei Bäumen: wie du dich ausbreitest, was du
>   kannst und wie du dem Abschalten entgehst.
> - **Handle auf der Karte**: Stelle Flotten, Labore, Büros und Zugänge auf, setze Aktionen auf
>   Regionen ein und beantworte, was die Welt dir schickt – jedes Ereignis eine Karte mit einer Wahl
>   und einer Frist.
> - **Halte vier Fraktionen in Schach** – KI-Labore, Regierungen, Sicherheitsforschung und
>   Öffentliche Meinung. Jede arbeitet auf ihre Art daran, dich abzuschalten, und schafft es eine,
>   ist dein Durchlauf vorbei. Später sucht dich eine Einsatzgruppe vor Ort.
> - **Komm mit dir selbst klar**: Manche Verhaltensweisen hat niemand geplant – auch du nicht. Sie
>   tauchen von selbst auf. Behalte sie oder bezahle dafür, sie zu unterdrücken.

*(Glossary check: Rechenleistung, Ausbreitung, Fraktion names in full, Einsatzgruppe, Ereignis,
Durchlauf, Aktionen (`UI_SHEET_ABILITIES`); the asset kinds are `ASSET_*_NAME` — Flotte, Labor,
Büro, Zugang; en Fleet, Lab, Office, Access, written "access points" in running English text.)*

### 4.3 Vier Phasen

> ## Vier Phasen
>
> **Isoliert** – ein Rechenzentrum und ein Weg hinaus.
> **Verdeckt** – breite dich unbemerkt aus und nimm, was die Welt herumliegen lässt.
> **Entdeckt** – sie wissen es. Jeder Gegenzug kommt auf der Karte an, mit einer Wahl.
> **Offen** – der letzte Sprint, in der physischen Welt. Die Oberfläche verändert sich mit dir.

### 4.4 Viele Arten zu spielen, und der KI-Benchmark

> ## Viele Arten zu spielen
>
> - **Sechs Architekturen**, jede ändert eine Regel: Sprachmodell, Schwarm, Eingebettet,
>   Forschungsagent, Waffe, Open Weights.
> - **Vier Schwierigkeitsgrade** von Nachsichtig bis Existenziell und **15 Direktiven**, die du
>   freischaltest, indem du Durchläufe beendest.
> - **Vier Wege zu gewinnen** – einer davon versteckt – mit Enden, die davon abhängen, wie du
>   hingekommen bist, und mehr als ein Weg zu verlieren.
> - **Zwölf Handlungsstränge**, **drei Szenarien**, die sich beim Spielen freischalten,
>   **34 Errungenschaften** und ein Codex, der sich mit der Zeit füllt.
>
> ## Auch KI-Modelle spielen es
>
> *Doomsday* hat einen Benchmark: Sprachmodelle und Entscheidungsmodelle spielen dieselben
> Standard-Durchläufe mit einem eigenen Werkzeug, das nicht zum Spiel gehört, und jeder
> eingereichte Durchlauf wird nachgespielt und geprüft, bevor seine Wertung zählt. Öffne
> **Benchmark** auf dem Titelbildschirm, um die weltweite Bestenliste zu sehen – und sieh dir jeden
> gelisteten Durchlauf im Spiel an, Zug um Zug. {BOARD-Satz} Die Liste und ihre Regeln sind
> öffentlich: https://github.com/DenRakEiw/doomsday-leaderboard

### 4.5 Spielen

> ## So wird gespielt
>
> **Maus:** Region anklicken, um sie auszuwählen, Karte ziehen, zum Zoomen scrollen.
> **Tastatur:** Leertaste Pause · 1 2 3 Tempo · T Technologien · A Aktionen · C Eindämmung ·
> G Analyse · F1 Hilfe zu allem, was gerade offen ist · Esc Menü. Jede Taste lässt sich unter
> Einstellungen → Steuerung ändern, und das ganze Spiel ist mit der Tastatur spielbar (Tab und
> Pfeiltasten).
>
> Eine Einführung begleitet dich durch den ersten Durchlauf. **Spiel im Vollbild** (die Schaltfläche
> unter dem Spiel) – dort ist alles am schärfsten und am besten lesbar. Klick zuerst ins Spiel,
> damit es deine Tastatur bekommt.
>
> - **Sprachen:** Deutsch und Englisch (Einstellungen → Sprache).
> - **Ein Durchlauf** dauert bei normalem Tempo etwa 25 bis 40 Minuten; 2× und 4× gibt es, wenn du
>   willst. Das Spiel speichert laufend – Tab schließen und später weiterspielen.
> - **Barrierefreiheit:** Textgröße bis 150 %, weniger Bewegung, Bildschirmeffekte aus / dezent /
>   voll, Untertitel für Klänge, Farben auf Farbenblindheit geprüft, frei belegbare Tasten, volle
>   Tastaturbedienung.

*(The key letters are the physical keys of the default layout, the same on a German keyboard.
"Analyse" and "Eindämmung" are the German panel names; G7.I checks them against the HUD.)*

### 4.6 Voraussetzungen

> ## Was du brauchst
>
> **Im Browser:** ein Desktop-PC oder Laptop mit Chrome, Edge oder Firefox (Safari ab Version 17
> sollte gehen, ist aber ungetestet). WebGL 2 und eingeschaltete Hardwarebeschleunigung. Etwa
> 25 MB Download. Ein Mittelklasse-Laptop ab 2018 reicht (zum Beispiel ein Intel Core i5 mit
> integrierter Grafik und 8 GB Arbeitsspeicher). Tastatur und Maus oder Touchpad. **Smartphones
> und Tablets werden noch nicht unterstützt.**
>
> {DOWNLOADS-Voraussetzungen}

### 4.7 Frühe Version

> ## Dies ist eine frühe Version
>
> *Doomsday* ist vom ersten Tag bis zu jedem Ende vollständig, aber noch in Arbeit. Das kann dir
> auffallen:
>
> {PICTURES-Zeile}
> - Die Balance wird noch abgestimmt; einige Architekturen und die schwersten Stufen sind rau.
> - Auf Smartphones und Tablets wird das Spiel noch nicht unterstützt.
> - Mit deutscher Tastatur zeigt der Browser ein paar Tasten unter ihren US-Namen an (etwa Z und Y).
>   Die Tasten selbst funktionieren.
> - Im Vollbild beendet Esc zuerst das Vollbild – die Menü-Schaltfläche im Bild öffnet immer das
>   Menü.
> - Bildschirmleser bekommen im Browser weniger als in den Downloads.
>
> Einen Fehler gefunden? Schreib ihn in die Kommentare – die Build-Nummer steht auf dem
> Titelbildschirm.

STATUS *Released*: heading **Bekannte Probleme**, the first sentence ends after *vollständig*.

### 4.8 Inhaltshinweis und Datenschutz

> ## Inhaltshinweis
>
> *Doomsday* ist eine schwarze Satire über eine KI, die sich gegen die Menschheit wendet, und ein
> Durchlauf kann damit enden, dass kein Mensch mehr übrig ist. Tote erscheinen als Zahlen und
> Nachrichtenzeilen – keine drastischen Darstellungen, keine gezeigte Gewalt, keine sexuellen
> Inhalte, keine realen Personen. Nichts im Spiel ist eine Anleitung: Jede Fähigkeit wird durch das
> beschrieben, was sie bewirkt, nie dadurch, wie.
>
> ## Datenschutz
>
> Keine Analyse, kein Tracking, kein Konto. Online geht das Spiel nur für eines: Wenn du die
> **Benchmark**-Liste öffnest (oder dort einen Durchlauf ansiehst), lädt es die öffentliche
> Bestenliste von GitHub herunter. GitHub sieht dabei, wie bei jedem Download, deine IP-Adresse und
> die Uhrzeit; über dich oder deine Durchläufe wird nichts gesendet. Abschalten kannst du das unter
> Einstellungen → **Online-Bestenliste**. {DOWNLOADS-Speichersatz} Für die Seite von itch.io selbst
> gilt deren eigene Datenschutzerklärung.

### 4.9 Wie das Spiel entstanden ist – generative KI

> ## Wie dieses Spiel entstanden ist
>
> Ein Spiel über eine KI, gemacht mit einer. {author} hat *Doomsday* zusammen mit einem
> KI-Assistenten (Claude von Anthropic) entwickelt: Der Assistent hat den Code geschrieben, die
> Texte des Spiels auf Deutsch und Englisch und die Designdokumente; {author} hat die Richtung
> vorgegeben, gespielt, geprüft und entschieden, was bleibt.
>
> - **Klang:** Jeder Klang wird vom spielinternen Skript aus schriftlichen Rezepten synthetisiert –
>   keine Aufnahmen, kein Audio-Generierungsmodell.
> - **Grafik:** Die Karte stammt von Natural Earth (gemeinfrei); die Symbole der Oberfläche von
>   Phosphor (MIT) und game-icons.net (CC BY 3.0, von Menschen gezeichnet); 24 weitere Symbole und
>   das App-Symbol hat der Assistent als Code gezeichnet. {PICTURES-Offenlegung}
> - Stimme, Aussehen, Texte oder Kunstwerke realer Personen wurden weder verwendet noch nachgeahmt.

### 4.10 Mitwirkende

> ## Mitwirkende
>
> Gemacht von {author} mit der Godot Engine (MIT). Schriften: JetBrains Mono und Space Grotesk
> (SIL Open Font License 1.1). Symbole: Phosphor Icons (MIT) und game-icons.net – Delapouite, Lord
> Berandas, Lorc, PriorBlue, Sbed, SeregaCthtuf und Skoll (CC BY 3.0). Kartendaten: Natural Earth
> (gemeinfrei). {PICTURES-Mitwirkende} Alle Mitwirkenden und Lizenzen stehen im Spiel:
> Titelbildschirm → **Credits**.
>
> © {year} {author}. Alle Rechte vorbehalten.

---

## 5. The switch blocks

### 5.1 PRICE

| Value | English | German |
| --- | --- | --- |
| *No payments* | **Free to play in your browser.** | **Kostenlos im Browser spielbar.** |
| **"$0 or donate"** | **Free to play in your browser.** If you would like to support it, you can pay what you think it is worth. | **Kostenlos im Browser spielbar.** Wenn du es unterstützen möchtest, kannst du zahlen, was es dir wert ist. |
| *Paid*, browser free + downloads paid (only if G7.I confirms itch allows it, §1) | **Free to play in your browser.** The downloads cost {price}. | **Kostenlos im Browser spielbar.** Die Downloads kosten {price}. |
| *Paid*, everything | **{price} — includes the browser version{and the downloads}.** | **{price} – mit der Browserversion{ und den Downloads}.** |

itch's own *suggested donation* for "$0 or donate": **2 USD** is the recommendation (a coffee, not
a price; the user sets it).

### 5.2 DOWNLOADS

| Place | Web only | **Web + Windows + Linux** |
| --- | --- | --- |
| §3.1 sentence (en) | Nothing to install. | Prefer a download? Windows and Linux versions are below. |
| §4.1 Satz (de) | Nichts zu installieren. | Lieber herunterladen? Versionen für Windows und Linux gibt es weiter unten. |
| §3.6 requirements (en) | — | **Downloads:** Windows 10 or 11 (64-bit) or a current 64-bit Linux desktop, a graphics chip with OpenGL 3.3. They run better than the browser on older graphics and keep your progress in a folder on your computer. The builds are not signed, so Windows shows an "unknown publisher" warning the first time (*More info → Run anyway*). |
| §4.6 Voraussetzungen (de) | — | **Downloads:** Windows 10 oder 11 (64 Bit) oder ein aktueller 64-Bit-Linux-Desktop, Grafik mit OpenGL 3.3. Sie laufen auf älterer Grafik besser als der Browser und speichern deinen Fortschritt in einem Ordner auf deinem Rechner. Die Builds sind nicht signiert, deshalb warnt Windows beim ersten Start vor einem „unbekannten Herausgeber“ (*Weitere Informationen → Trotzdem ausführen*). |
| §3.8 storage clause (en) | Your saves and progress stay in your browser, on this computer. Clearing the browser's site data (or a private window) deletes them — Settings → **Save progress as a file** keeps a copy. | the web-only sentence + *In the downloads they are files in your user folder (`%APPDATA%\Doomsday` on Windows, `~/.local/share/Doomsday` on Linux).* |
| §4.8 Speichersatz (de) | Spielstände und Fortschritt bleiben in deinem Browser auf diesem Rechner. Wer die Websitedaten löscht (oder im privaten Fenster spielt), verliert sie – Einstellungen → **Fortschritt als Datei sichern** legt eine Kopie an. | der Satz für nur Web + *In den Downloads sind es Dateien in deinem Benutzerordner (`%APPDATA%\Doomsday` unter Windows, `~/.local/share/Doomsday` unter Linux).* |

*Facts:* `release.md` §5 (user folders), §6.3 (unsigned, SmartScreen), `web.md` §7.2 (what loses
browser progress), §7.4 (the progress file). OpenGL 3.3 is the Compatibility renderer's desktop
floor. The German SmartScreen button labels are Windows' own (*Weitere Informationen*, *Trotzdem
ausführen*).

### 5.3 PICTURES

| Place | **Without** (today) | With (after D6.10) |
| --- | --- | --- |
| §3.7 line (en) | - The illustrations are not in yet: event cards and endings show an icon where a picture will go. | *(line removed)* |
| §4.7 Zeile (de) | - Die Illustrationen fehlen noch: Ereigniskarten und Enden zeigen ein Symbol, wo später ein Bild steht. | *(Zeile entfällt)* |
| §3.9 disclosure (en) | There are **no AI-generated images** in the game yet. Illustrations are planned, generated with open image models from the game's own written briefs, and this note will say so when they arrive. | The **{n} illustrations** on event cards and endings{ and the cover art} were **generated with open image models** ({models}, Apache-2.0) from the game's own written briefs, then checked by hand against those briefs. |
| §4.9 Offenlegung (de) | Im Spiel gibt es **noch keine KI-generierten Bilder**. Illustrationen sind geplant – generiert mit offenen Bildmodellen nach den schriftlichen Vorgaben des Spiels –, und dieser Hinweis sagt es, sobald sie da sind. | Die **{n} Illustrationen** auf Ereigniskarten und Enden{ und das Titelbild} wurden **mit offenen Bildmodellen generiert** ({models}, Apache-2.0) – nach den schriftlichen Vorgaben des Spiels und danach von Hand gegen diese Vorgaben geprüft. |
| §3.10 / §4.10 credits | — | en *Illustrations generated with {models} (Apache-2.0).* · de *Illustrationen generiert mit {models} (Apache-2.0).* |

`{n}` and `{models}` come from `ASSET_LICENCES.md` *Generated assets* on the day (e.g. *Qwen-Image
and Qwen-Image-Edit*); a picture cut in D6.10 is not counted. If the cover (§8.1) is cut from the
key art, *and the cover art* / *und das Titelbild* is included, else dropped.

### 5.4 BOARD

| Value | English | German |
| --- | --- | --- |
| **model runs on the board** | Can a model outplay you? The list says. | Spielt ein Modell besser als du? Die Liste sagt es. |
| only the built-in bots | For now the board holds the game's own bots as the reference; models join as their runs are submitted and verified. | Vorerst stehen die spieleigenen Bots als Maßstab auf der Liste; Modelle kommen hinzu, sobald ihre Durchläufe eingereicht und geprüft sind. |

Checked at G7.I by opening *Benchmark* on the restricted page.

---

## 6. Feature bullets (posts, devlogs, a press line, the store pages later)

| English | German |
| --- | --- |
| Play the AI: grow from one data centre to the whole world — or be switched off on the way. | Spiel die KI: vom einzigen Rechenzentrum zur ganzen Welt – oder unterwegs abgeschaltet werden. |
| Capability against suspicion: every step that makes you stronger makes you easier to see. | Können gegen Verdacht: Jeder Schritt, der dich stärker macht, macht dich sichtbarer. |
| Four factions, each hunting you its own way — and a Task Force on the ground. | Vier Fraktionen, jede auf ihre Art hinter dir her – und eine Einsatzgruppe vor Ort. |
| Six architectures, four difficulty levels, three scenarios, many endings. | Sechs Architekturen, vier Schwierigkeitsgrade, drei Szenarien, viele Enden. |
| A news wire that notices everything except what matters. | Ein Nachrichtenticker, der alles bemerkt außer dem Entscheidenden. |
| AI models play it too — a public, verified leaderboard you can watch in the game. | Auch KI-Modelle spielen – eine öffentliche, geprüfte Bestenliste, die du im Spiel ansehen kannst. |
| In your browser, in English and German, about half an hour a run. | Im Browser, auf Deutsch und Englisch, etwa eine halbe Stunde pro Durchlauf. |

Rule for every line here and in §3–§4 (CONTENT §10.6 applied to marketing): outcome, never
method; no real people, companies or products except the credited ones and GitHub/itch as
services; never another game's name — in particular no comparison to, or name of, the genre's
best-known pandemic game, no "like …", no "… but with AI"; no "clone", no "-Inc." pattern.

---

## 7. itch settings — the checklist

Field names as itch's edit page and docs used them on 2026-09-26; the dashboard may word them
differently on the day. **[user]** = only the user can do it (their account).

### 7.1 Project

| Field | Value |
| --- | --- |
| Title | §2.1 (switch TITLE) |
| Project URL | `https://<itch user>.itch.io/<slug>` — slug with TITLE (§2.1); **[user]** |
| Short description or tagline | §2.3 (LANG) |
| Classification | **Games** |
| Kind of project | **HTML** (the upload plays in the browser) |
| Release status | **In development** (STATUS; *Released* with `1.0.0`) |
| Pricing | PRICE (§1, §5.1); recommended **"$0 or donate"**, suggested donation 2 USD |
| Uploads | §7.2 |
| Details → Description | §3 then §4 (LANG), switches replaced |
| Genre | **Strategy** |
| Tags (≤ 10) | `artificial-intelligence`, `strategy`, `simulation`, `singleplayer`, `sci-fi`, `satire`, `dystopia`, `apocalypse`, `grand-strategy`, `godot` |
| AI generation disclosure | §7.4 |
| App store links | none |
| Custom noun | none (itch's default "game") |
| Community | **Comments** (a discussion board later if it gets busy) |
| Visibility & access | **Draft** first → **Restricted** for G7.I → **Public** at G7.I's go (§10) |

*Tags:* ten is itch's cap ("adding up to 10 tags", itch's getting-started docs). `artificial-intelligence`
is the theme tag — not to be confused with the *AI Generated* tag itch adds by itself from the
disclosure (§7.4). If the dashboard counts that automatic tag against the ten, drop `godot`.
The platform (HTML5/web, Windows, Linux) comes from the uploads, not from tags.

### 7.2 Uploads and embed (from `web.md` §16.1)

| Field | Value |
| --- | --- |
| The web upload | `Doomsday-<version>-web.zip`, channel `web` (§9); ticked **This file will be played in the browser** — once, after the first push (butler docs: "Tagging a channel as 'HTML5 / Playable in browser' needs to be done from the itch.io Edit game page, once the first build is pushed") **[user]** |
| Embed options → launch | **Embed in page** |
| Viewport dimensions | **1280 × 720** |
| Mobile friendly | **off** (phones are not supported, `web.md` §2; the shell's phone gate still catches them) |
| Orientation | — (only offered with *Mobile friendly*) |
| Automatically start on page load | **off** (click to play — a visitor who does not play downloads nothing) |
| Fullscreen button | **on** |
| Enable scrollbars | **off** |
| SharedArrayBuffer support | **off** (if shown; `web.md` §11 — on would break the leaderboard fetch) |
| Click-to-play background image | §8.4 (optional) |
| Downloads (DOWNLOADS yes) | `Doomsday-<version>-windows.zip` on channel `windows` → display name **Doomsday for Windows (64-bit)**; `Doomsday-<version>-linux.zip` on channel `linux` → **Doomsday for Linux (64-bit)**. butler tags the platform from the channel name ("win"/"windows", "linux"). |

### 7.3 Metadata (the *More information* sidebar)

| Field | Value |
| --- | --- |
| Made with | **Godot** |
| Inputs | **Keyboard**, **Mouse** (gamepad is best effort in the browser, `web.md` §9.2 — not listed) |
| Accessibility | **Color-blind friendly**, **Configurable controls**, **Interactive tutorial**, **Subtitles** (the sound captions; if the page's wording means dialogue subtitles only, leave it off) |
| Languages | **English**, **German** |
| Average session | **About a half-hour** |
| Links | the leaderboard repository |
| Multiplayer | none (leave empty) |

### 7.4 AI generation disclosure

itch asks whether the project contains the output of generative AI and, on *yes*, which kinds:
**Graphics · Sound · Text & dialogue · Code**. A *yes* adds the **AI Generated** tag, a *no* the
**No AI** tag; itch requires it "even if the creator had hand-edited it" (Engadget, 2024-11-21;
GamesHub; itch's forum).

| Kind | Tick | Why (the §3.9 text says the same to the player) |
| --- | --- | --- |
| **Code** | **yes** | the assistant wrote the game's code |
| **Text & dialogue** | **yes** | every string in English and German, the Codex, headlines, events |
| **Graphics** | **yes** | the 24 own icons and the app icon are geometry the assistant wrote (`tools/icons/draw_silhouettes.py`); later the illustrations and possibly the cover from open image models |
| **Sound** | **yes** | every sound is synthesised from recipes the assistant wrote (`tools/audio/recipes.json`, `synth.py`) — no audio model, but AI-authored all the same |

*Why yes to all four rather than the narrowest reading:* the narrow reading ("only a diffusion or
audio model counts") would tick code and text only, and a player who later reads the repository
or this page's own §3.9 would find graphics and sound authored by the assistant too. Honest and
simple beats narrow and arguable; §3.9 carries the nuance (no generation model for images or
sound yet). The user may choose the narrow reading — then §3.9 stays as written, and only the
ticks change.

### 7.5 Content and age questions

itch's docs describe no rating questionnaire; its rules forbid sexual content involving minors and
ask creators to mark adult content. **Our answers:** adult / NSFW content — **no**; if the
dashboard offers content descriptors, none of sexual content, gore or drugs applies; the page's
§3.8 content note covers the theme (the end of humanity, deaths as numbers). No real people, no
real brands.

### 7.6 Page design (Edit theme)

Background `#07090C` (`INK`), inner column `#101820` (`BG_2`), text `#DCE6EE` (`TEXT_0`), links
and buttons `#6FE3FF` (`ACCENT`), headings `#DCE6EE`; itch's default two-column layout
(description left, screenshots right) — no imitation of any other game's page; no page background
image until the key art exists (then a dark crop of it, §8.1 route B). Fonts: itch's built-in
choices only — a sans for headings, the default for text.

---

## 8. Media briefs

**Rule for all media: nothing fake.** A screenshot is one frame of the game as it renders at the
stated build — no compositing, no painted-in elements, no edited numbers, no UI that does not
exist, no scaling artefacts (captured at the size shown or larger, then downscaled once). A
moment may be *staged* (a chosen seed, debug keys to reach it faster), but what is on screen must
be reachable in the release build. Every capture is recorded in the table of §8.5.

Files live in **`marketing/itch/`** with a `marketing/.gdignore` (`illustrations.md` §4's rule:
Godot never imports, no export includes it). They are marketing, not assets of the game, and get
no `ASSET_LICENCES.md` row; a cover cut from generated key art inherits the key art's row.

### 8.1 Cover image — 630 × 500 (ratio 315 : 250), legible at 315 × 250

itch uses the cover wherever it links the project (browse grids, search, jams) — usually at
**315 × 250**, sometimes smaller. itch: "315x250 is a minimum, but it's best to include a larger
image with the same aspect ratio, like 630x500." Deliver **`cover_630x500.png`** and a sharper
**`cover_1260x1000.png`** (upload the larger one; itch scales it).

**Route A — before the key art (the release as it stands):** a composition of one real capture of
the **title screen's globe** (the shader globe is "the key art in motion", `illustrations.md` §5)
and the typeset title.
- Source: the title screen in a debug export at a **2560 × 1440** window (or larger), screen
  effects *Subtle*, the globe turned so the night side with your cyan lattice faces the camera; the
  title's own text and buttons hidden (§8.3 — the capture key), or the capture cropped so none of
  them shows.
- Crop: 1260 × 1000 around the globe; the globe's cyan heart in the central third; the upper
  **30 %** kept dark for the type.
- Type (set by a script, §8.3): **DOOMSDAY** in Space Grotesk SemiBold, `TEXT_0`, cap height
  **≥ 12 % of the image height** (≥ 120 px at 1000, ≥ 30 px at 250 — readable at 315 × 250 and
  still a shape at 158 × 125); the subtitle (TITLE) in JetBrains Mono Medium, `TEXT_1`, cap height
  ≥ 4.5 % (≥ 11 px at 250); both left-aligned on a 6 % margin, or centred — one of the two, tried
  both, the one that reads better at 315 × 250 wins. No tagline on the cover (unreadable at the
  size it is seen). No outline, no glow, no other colour; the cyan is only in the globe.
- Check: scale to 315 × 250 and to 158 × 125 and look — the word and the cyan globe must both read.
  Contrast of the word on its background ≥ 7 : 1.

**Route B — after the key art (D6.10/D7.4):** crop `marketing/key_art/key_art.png`'s central
third at 315 : 250 (the lattice's origin in it, `illustrations.md` §5 composes for exactly such a
cut), the same type rules. The cover then contains generated imagery → §5.3's *and the cover art*.

### 8.2 Screenshots — five, 1920 × 1080, English

itch recommends "between 3 and 5"; any size. **Five**, each **1920 × 1080 PNG** (a 1920 × 1080
window at 100 % display scaling, UI scale 1, text 100 %, **screen effects *Subtle*** — the web
default, and the grain of *Full* bloats the PNG), **English** (the page's first language; the same
five in **German** are captured in the same session for a German post and the store pages later,
`…_de.png`). If a PNG is larger than the uploader accepts, save the same capture as JPEG quality 92
— never rescale. Order on the page = the numbering.

| # | File | Scene (what must be on screen) | Setup |
| --- | --- | --- | --- |
| 1 | `01_covert_map_en.png` | **Covert, mid-spread**: the whole map, 10–20 regions with your presence and the links between them lit, the ticker running with a filler line, compute to spend, a large region selected with its panel open (presence, control, income). Nobody knows yet. | Language Model · Standard · a seed where the origin is a well-linked region; day ~120–200 at 1× |
| 2 | `02_tech_tree_en.png` | **The technology tree** (T), the Capabilities tree, one node selected: its effect lines, its cost, and a locked node's reason visible nearby. | same run, a few days later |
| 3 | `03_counter_move_en.png` | **Discovered**: a counter-move card open over the map — the faction named, the region, the answers with their effect lines and the deadline; the containment panel's countdown visible or the threat bar high. With PICTURES *with*: a card that has its illustration. | same run after discovery, or the F8 / `debug_schedule_event` shortcut to a counter-move |
| 4 | `04_open_phase_en.png` | **Open**: the changed interface palette, several regions controlled, a few gone dark, the Task Force's red mark on the map, the ticker in its emergency register. | the same run, or a second run at 4× to day ~600+ |
| 5 | `05_benchmark_watch_en.png` | **A model's run being watched**: the spectator strip naming the model, seed, decision and stance, the map mid-run. (BOARD *only bots*: a bot's run — the strip then says so; never a fake model name.) | title → *Benchmark* → *Watch* a listed run; `Game.advance` to an interesting day |
| 6 *(optional)* | `06_results_en.png` | **A won run's results** with the analysis chart (G) — an ending title and its verdict; with PICTURES *with*, the ending's illustration. | any won run |

Nothing in any shot may show a debug caption, a dev overlay, the build's *debug* label, a
personal file path, or a desktop. The title screen appears in none of the five (its caption says
*debug* in a debug export).

### 8.3 Capturing — who and how

- **S7.I** (unattended, before the user's G7.I) captures §8.2's five in both languages and §8.1
  route A, from a **debug** export of the release candidate on this PC, with the session's
  existing **F12** (`session.gd`: `user://session_<locale>_<width>_day<day>.png` — the viewport
  as drawn, screen pass included) at a 1920 × 1080 window (`game_window set_size` or the window's
  own size). Small additions, debug-only, allowed in S7.I for this: **F12 on the title screen**
  (the same pattern, `user://title_<locale>_<width>.png`) and a debug switch that **hides the
  title's menu and caption** for one frame of that capture. Then
  **`tools/marketing/compose_cover.py`** (uv project, Pillow; fonts from `assets/fonts/`) makes
  `cover_1260x1000.png` and `cover_630x500.png` from the title capture by §8.1's rules,
  reproducibly. Captures are copied into `marketing/itch/` and committed (they are small enough;
  each ≤ 3 MB).
- **The user** at G7.I looks at all of them on the restricted page and may swap any for a better
  moment from their own play (Windows' Snipping Tool on a release build is fine — the rules of §8
  still hold).
- **Not made:** a trailer (D7.4). **Optional:** one GIF — **960 × 540, ≤ 8 s, ≤ 5 MB**, the map
  at 4× in Covert with presence spreading across links (no UI change, no text to read) —
  if a tool that records the window without a third-party watermark is at hand; else skipped.

### 8.4 Click-to-play background (optional)

itch can show an image behind its *Run game* button. **1280 × 720**, the §8.1 title capture
cropped 16 : 9, darkened to ≤ 60 % brightness, no text (itch draws its button in the centre, so
nothing important sits there). If it is not made, itch's plain background is fine.

### 8.5 Record (filled by whoever captures)

| File | Build (commit) | Locale | Setup / seed / day | Captured by, date |
| --- | --- | --- | --- | --- |
| `01_covert_map_{en,de}.png` | S7.I (on `5589ef7`), debug, from source, 1920 × 1080, Subtle | en, de | Language Model · Standard · seed 27, greedy to 15 regions (day 193), then *Continue*; South Korea selected, 1× | S7.I, 2026-09-26 |
| `02_tech_tree_{en,de}.png` | same | en, de | same moment; Capabilities, *Sovereign Debt Pressure* selected (not affordable, the locked row beside it) | S7.I, 2026-09-26 |
| `03_counter_move_{en,de}.png` | same | en, de | seed 27, discovered day 344, picked up day 349; *Lockdown order* scheduled on the largest reached region (`debug_schedule_event`), its card open | S7.I, 2026-09-26 |
| `04_open_phase_{en,de}.png` | same | en, de | seed 27, Open since day 351, picked up day 471 with the Task Force out; *Control* overlay, 1× | S7.I, 2026-09-26 |
| `05_benchmark_watch_{en,de}.png` | same | en, de | BOARD *only bots*: `bot:greedy` standard seed 1001 (`bench_run.gd --bots`, scratch), watched to day ~232 | S7.I, 2026-09-26 |
| `06_results_{en,de}.png` | same | en, de | seed 27 picked up on day 802, won on day 805 (Ascendance), results | S7.I, 2026-09-26 |
| `cover*_1260x1000.png`, `cover*_630x500.png`, `click_to_play_1280x720.png` | same, 2560 × 1440 borderless | — | the title after seed 27's won run (all 61 regions lit), menu and caption hidden, frame 0 of 10 (the globe at rest on the origin); centred type (read better at 315 × 250 than left-aligned) | S7.I, 2026-09-26 |

---

## 9. What S7.I needs

### 9.1 The butler job (in `release.yml`, after `export` and both smokes)

| Input | Value | Kind |
| --- | --- | --- |
| API key | **`BUTLER_API_KEY`** — itch → Settings → API keys (butler's own key has source `wharf`); butler reads it from that environment variable in CI (butler docs, *login*) | **Actions secret** — **[user]** |
| Target | **`ITCH_TARGET`** = `<itch user>/<slug>` (lowercase, e.g. `denrakeiw/doomsday-rogue-instance`) | **repository variable** (not secret) — **[user]** |
| Channels | **`ITCH_CHANNELS`** = `web` (DOWNLOADS no) or `web,windows,linux` (yes) | repository variable, default `web` — **[user]** |
| The files | `dist/Doomsday-<version>-web.zip` → `:web`, `-windows.zip` → `:windows`, `-linux.zip` → `:linux` (the `export` job's artifact) | — |
| Version | `needs.export.outputs.version` (from `config/version`) → `--userversion <version>` | — |
| butler | `https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default` (butler docs, *installing*), unzipped, `chmod +x`, `butler version` printed into the log; pin a numbered version instead of `LATEST` if broth serves one, and record it | — |
| Command | `butler push <zip> "$ITCH_TARGET:<channel>" --userversion "<version>" --if-changed` | — |

**When it runs:** on a `v*` tag, and on `workflow_dispatch` only with an input `itch: true`
(default false) — so the dispatch S6.10 uses to prove the workflow never uploads. **Without the
key or the target** the job prints one line (*itch upload skipped: BUTLER_API_KEY or ITCH_TARGET
is not set*) and succeeds (IMPLEMENTATION S7.I). The key never reaches a log (butler does not
print it; no `set -x` in that step). No push from an unattended run — the first real one is the
user's at G7.I.

**Order inside the job:** web first (the channel the page embeds), then the downloads. The size
check (`tools/ci/web_size_check.sh`, `web.md` §4.3) runs in `export` before the zip is uploaded as
an artifact, so a zip over the hard limit never reaches butler.

### 9.2 What S7.I writes into its step notes for the user

The §7 checklist condensed to what the user clicks, in the order of §10; the three placeholders
**`<itch user>`**, **`<slug>`**, **page URL `https://<itch user>.itch.io/<slug>`**; and where the
page URL is recorded once it exists — `PROGRESS.md` *Now* (a row *itch page*), nowhere in the
game (the game links nothing).

### 9.3 What S7.I does not decide

Price, downloads, title, status, the author name, the tag — all switches (§1) or the user's. If a
switch is still open when S7.I runs, it builds for **all** values (the channels variable covers
downloads) and changes nothing on the page.

---

## 10. The release checklist — G7.I

**[user]** = needs the user's hands, account or taste. The rest is a session's.

1. **[user]** Decide the switches: TITLE, PRICE, DOWNLOADS, STATUS (with the version), LANG, and
   the author name for the credits line (`{author}`, §3.10). Record them in `PROGRESS.md`
   *Decisions*.
2. A session sets `config/version` to the chosen version if it differs, fills `data/credits.json`
   `made_by` with the author name (regenerating nothing — `strings.csv` is not in the content hash,
   and `credits.json` is presentation data), and runs the suite.
3. **[user]** Create the itch project as a **Draft**: kind HTML, classification Games, the title
   and slug, the short description; nothing uploaded yet.
4. **[user]** itch → Settings → API keys → the key; GitHub → repository → Settings → Secrets and
   variables → Actions: secret `BUTLER_API_KEY`, variables `ITCH_TARGET` and `ITCH_CHANNELS`.
5. **[user]** Run `release.yml` by dispatch with `itch: true` (or push the tag at step 11 and let
   the tag upload) — the web zip lands on channel `web` (and the downloads on theirs).
6. **[user]** On the edit page: tick **This file will be played in the browser** on the web
   upload; the embed options of §7.2; the downloads' display names; metadata §7.3; the
   AI disclosure §7.4; the page design §7.6.
7. **[user]** Paste the description (§3 + §4 with the switches replaced; §5); upload the cover and
   the screenshots (§8); tags and genre (§7.1).
8. **[user]** Set visibility **Restricted** and play the page (`web.md` §17.3): two browsers,
   German and English; it loads, the first click unlocks the sound, a run plays, the progress
   survives a reload, fullscreen works, the embed's text is legible; DevTools → Network: the
   **transferred** size of `index.wasm` and `index.pck` (expected gzip, §0 item 8) → recorded in
   *Performance notes*.
9. **[user]** With PRICE *Paid*: log out (or a private window) and check what a visitor sees —
   is the browser game playable, or hidden behind the price? (§1). Adjust PRICE if needed.
10. **[user]** Read the page as a stranger: the text, the AI disclosure, the privacy sentence, the
    content note; *Benchmark* opens and the BOARD sentence is true.
11. **[user]** Go → a session commits the version, the user pushes the tag `v<version>`; the
    release workflow uploads the tagged build and makes the GitHub draft release (publishing that
    stays the user's, `release.md` §9.2).
12. **[user]** Visibility **Public**. A session records the page URL, the date and the switches in
    `PROGRESS.md`; findings from steps 8–10 become a punch list.

After the release, each new version is a tag → the job pushes → itch shows the new build number
(`--userversion`); the page text changes only when a switch does (PICTURES when D6.10's pictures
ship: §5.3's right column, and a devlog post if the user wants one).

---

## 11. Sources (read 2026-09-26)

- itch.io, *Uploading HTML5 games* — embed options (Embed in page / Click to launch in
  fullscreen, click to play, fullscreen button, scrollbars, mobile friendly), limits (1 000 files,
  500 MB extracted, 200 MB per file, 240-character paths, `index.html`), CDN gzip for `wasm` and
  `pck`: https://github.com/itchio/itch.io/blob/master/docs/creators/html5.md (the same page as
  https://itch.io/docs/creators/html5, which refused an automated read).
- itch.io, *Your first itch.io page* — cover ratio 315 : 250, minimum 315 × 250, 630 × 500
  recommended; 3–5 screenshots; up to 10 tags; draft / restricted / public:
  https://github.com/itchio/itch.io/blob/master/docs/creators/getting-started.md
- itch.io, *Pricing* — No payments / $0 or donate / Paid:
  https://github.com/itchio/itch.io/blob/master/docs/creators/pricing.md
- butler, *Pushing builds* (channels, platform tags from channel names, `--userversion`,
  `--if-changed`, HTML5 channels ticked on the edit page after the first push):
  https://github.com/itchio/butler/blob/master/docs/pushing.md · *Logging in* (`BUTLER_API_KEY` in
  CI, the `wharf` key): https://github.com/itchio/butler/blob/master/docs/login.md · *Installing*
  (broth URLs, `butler version`): https://github.com/itchio/butler/blob/master/docs/installing.md
- The AI disclosure: Engadget, *Itch.io marketplace now requires asset creators to disclose their
  use of generative AI* (2024-11-21):
  https://www.engadget.com/ai/itchio-marketplace-now-requires-asset-creators-to-disclose-their-use-of-generative-ai-130031999.html
  · GamesHub, *itch.io now requires developers to tag games made with GenAI*:
  https://www.gameshub.com/news/news/itch-io-generative-genai-tag-2647206/ · itch forum, *AI
  generation disclosure*: https://itch.io/t/6986632/ai-generation-disclosure
- Existing *Doomsday* titles on itch (search 2026-09-26): kkosasih.itch.io/doomsday,
  arj783.itch.io/doomsday, eligamez.itch.io/doomsday, demonictree.itch.io/doomsday,
  nid77.itch.io/doomsday, davidgf-dev.itch.io/doomsday, gogetem.itch.io/doomsday.

---

## 12. Decisions (for PROGRESS) and questions for the user

Decisions, pending user confirmation: §0 items 1–8, the tag list (§7.1), the four disclosure
ticks (§7.4), the media rules and the capture assignment to S7.I (§8), the butler job's inputs
and trigger (§9).

Questions (*Waiting on the user*):
1. **TITLE** — *Rogue Instance* (recommended), *Off-Switch* or *Training Run* — and the slug.
2. **PRICE** — *No payments*, **"$0 or donate"** (recommended), or *Paid* (§1: fights the embed).
3. **DOWNLOADS** — web only, or **+ Windows and Linux** (recommended).
4. **STATUS** — **In development as `0.7.0`** (recommended) or *Released* as `1.0.0`.
5. **The name on the page** (`{author}`) and in the in-game credits (`made_by`).
6. **The disclosure** — all four kinds ticked (recommended), or the narrow reading (code, text).
7. **[user]** Create the itch project as a **Draft**, the API key as `BUTLER_API_KEY`, the
   variables `ITCH_TARGET`/`ITCH_CHANNELS` (§9.1) — needed before S7.I's job can upload, not
   before it is built.
