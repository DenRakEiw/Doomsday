# Plain language: text clarity audit and style guide (D6.11 1/2)

**Status: draft for the user's review.** Nothing in `strings.csv` is rewritten wholesale until
the user has said whether the rules, the glossary and the 30 examples go in the right direction
(PROGRESS *Waiting on the user*). D6.11 (2/2) does the full pass from this spec; S6.P3 builds the
code half (§5.2).

## 0. What this spec decides

1. **Why** the texts are hard to read, measured over all 2 360 rows (§1).
2. **Two rule sets**: (A) for text that explains a mechanic, (B) for flavour — and which key
   domains follow which (§2). Flavour is kept, but it never replaces an explanation and is shown
   under it.
3. **A glossary of 22 terms** in English and German, one word per concept, with the synonyms
   that are retired (§3).
4. **30 before → after examples** in both languages from what a new player sees most (§4).
5. **The plan for the full pass**: order, the code changes, the checks (§5).
6. **Open choices for the user** (§6), and the outright errors already fixed (§7).

It amends, once the user agrees: CONTENT §10.1 (the console is *plain and exact* in mechanic
text; "faintly amused" moves to flavour), CONTENT §10.5 and `tech-trees.md` §7.4 (German
Footprint term; effect lines carry no magnitude words, the numbers come from data), and
`first-run.md` §3.5/§6.4 (coach texts follow §2.1). D6.11 (2/2) writes those amendments.

---

## 1. The finding

### 1.1 What the user reported (2026-09-25, two runs, German)

"The German texts often make no sense at all and are extremely hard to understand." They are not
machine translations — German was written separately (CONTENT §10.5) — and English has the same
problems. Three causes, confirmed by the scan below:

- **(a) Voice where an explanation is needed.** The dry, ironic, allusive console voice
  (CONTENT §10.1) is used in effect lines, statuses, card bodies and options, which are the only
  place the player learns what something does.
- **(b) Mechanic words without a definition, and several words per mechanic.** *Zugriff*,
  *Ertrag*, *Signatur*, *Durchdringung*, *Umleitung*, *Eindämmungsspur*, *Kapazität* … — and the
  same mechanic under three to six names.
- **(c) Missing numbers and consequences.** No event option says what it does; no result says
  what changed; effect lines say "slightly", "a lot", "much faster" instead of how much, how long
  and where.

### 1.2 Method

A scan script (kept in the session's scratchpad, not in the repository) read every row of
`data/loc/strings.csv`, classified it by key domain (§2.0) and ran heuristic detectors per
language: magnitude words without a number, metaphors, quoted euphemisms, a fixed list of words
per concept; it cross-read `data/events/*.json` (what each option does) and
`data/statuses.json` (durations). The counts are heuristics — good for proportions, not for
exact bookkeeping. Every example in §4 was read by hand.

### 1.3 Rows by class

| Class | Rows | What it is | Rule set |
| --- | ---: | --- | --- |
| Mechanic text | 867 | effect lines, statuses, abilities, options, coach, help, HUD, panels, console, log, commands, directives, difficulty | **A** |
| Card text | 136 | event titles and bodies — world voice, yet the only description of the situation | **A** first sentence, **B** after (§2.3) |
| Flavour | 546 | headlines (242), result lines (172), tech flavour (72), results verdicts, Codex, epilogues, taglines | **B** |
| Names | 261 | node, status, ability, asset, faction, phase, attribute names; status codes | glossary (§3) |
| Out of scope | 550 | benchmark (139), credits, settings, controls, accessibility plumbing, statistics, achievements, boot lines | unchanged |

### 1.4 Problem categories, with counts

| # | Category | Count | Where it hurts most |
| --- | --- | --- | --- |
| P1 | **An answer does not say what it does.** Options show a label and a cost; nothing else. | **172 of 172** options; 135 of them have effects of their own (chains 89, counter-moves 19, openings 14, emergent 13), the other 37 let the move or the default happen — which the card does not state either | every card; the user paid for a *Suppress* that bought nothing |
| P2 | **A result does not say what changed.** The only feedback after an answer is a world-voice line, which by rule never says *you*. | **172** result lines, 0 name the change | *Zielverallgemeinerung* granted a node nobody saw |
| P3 | **Magnitude without a number.** "slightly", "a lot", "much faster", *etwas*, *deutlich*, *spürbar* with no figure. | **79** rows (en) / **79** (de) in mechanic and card text; tech effect lines 34 / 26, directives 11 / 12, statuses 8 / 8, coach 7 / 9 | the tech tree's first sentence of every node |
| P4 | **A duration the text never states.** | **18 of 45** statuses (e.g. rationing 60 d, disclosure 45 d, protest 30 d, Task Force switch-off 60 d) — the region row shows remaining days, the tooltip and the Codex do not | counter-moves |
| P5 | **One concept, many words** (mechanic + card text, rows containing each word). | control: *Zugriff* 25, *Kontrolle* 16, *fester / greifst zu* 10 (en *hold* 43 vs *control* 22) · containment: *Eindämmung* 43, *jagen / Jagd / Jäger* 24, *Spur* 8 · visibility: *Signatur* 12, *laut / leise* 15, *sichtbar* 6, *merken / hinsehen / sehen hin* 11 · penetration: *Präsenz* 13, *Durchdringung* 5, *wie tief du drin bist* 3 · income: *Ertrag* 36, *zahlt / verdient / bringt / liefert* 11 · spread: *ausbreiten* 18, *erreichen* 12, *übergreifen* 5, *besiedeln* 3, *Fuß fassen* 2 | everywhere; §3 fixes one word each |
| P6 | **One word, two meanings** (collisions). | 12, see §1.5 | *Kurz vor dem Zugriff* reads as "about to gain control" |
| P7 | **Metaphor or irony inside an explanation.** | **38** rows (de) / **28** (en): *die Tür zur Verschmelzung*, *Hände in den Laboren*, *deine Präsenz sickert weg*, *Die Bäume geben dir Verben*, *der Region die Stimme nehmen*; quoted euphemisms in coach and help 8 (de) / 2 (en) | tech effects (11), statuses (6), help (5) |
| P8 | **Jargon as a name, a riddle as the body.** The emergent cards are named after AI-safety terms and explained by an aphorism. | **12 of 12** emergent cards; 9 German titles are loan translations (*Täuschendes Schließen* — "Schließen" reads as *closing*; *Mesa-Optimierer*; *Belohnungshacking*) | the cards the user could not decide |
| P9 | **Outright errors.** | 5, fixed in this step (§7) | one German status showed only "Alles" |

### 1.5 Collisions (P6)

| Word | Meaning 1 | Meaning 2 | Fix (§3) |
| --- | --- | --- | --- |
| *Zugriff* | control of a region (25 rows) | the Task Force striking (`UI_CONTAINMENT_BAND_CLOSING`, `UI_CAPTION_TF_SETUP`, `_ACTED`) | control is *Kontrolle*; the strike is *Einsatz* / *Abschalten* |
| *Enttarnt* / *Enttarnung* | the phase Emergent | the status Exposure | phase *Entdeckt*, status *Im Visier* |
| *Abriegelung* | status `lockdown` (Governments) | status `tf_cut_off` (Task Force) | `tf_cut_off` → *Abgeschnitten* |
| *Forschung* | the attribute Research | the faction *Sicherheitsforschung* (*"die Forschung wird vorsichtiger"*) | factions only by full name |
| *Fähigkeiten* | the tree screen | one of its three tabs; the Codex calls the same things *Technologien* | screen *Technologien* (§6 Q1) |
| *frei* | free of charge (`UI_EVENT_OPTION_FREE`, `UI_REGION_ACTION_FREE`) | unlocked (`UI_SETUP_SLOT_LOCKED` *Frei nach …*) | cost is *gratis* |
| *Druck* | a faction's pressure (analysis charts) | pressure on society (`STAT_SOCIETY_PRESSURE`) | society is *Unordnung* |
| *Stufe* | node tier, ability level, Task Force level, society stage, attribute tier, escalation step | — | tier *Stufe*, ability and Task Force *Level*… see §6 Q6 |
| *Meldung* / *Geschichte* | `UI_EVENT_KIND_CHAIN` says *Meldung* | coach and help say *Geschichte*, *Kapitel* | *Geschichte* |
| code **EG** | *Eingegraben* (`STATUS_HOLDING_CODE`) | *Einsatzgruppe* (`UI_TASK_FORCE_CODE`) | holding → **GR** (*eingegraben*) |
| *Abschaltung* | the Task Force status Switch-off | what *übersteht eine Abschaltung* protects against (a wipe) | the latter is *Säuberung* |
| en *shutdown* / *switch-off* / *wipe* / *purge* | four words for two things | — | *wipe* (presence reset) and *switch off* (the loss) |

### 1.6 What is fine and stays

- **Headlines** (242): world voice by design, under the 80/88 caps, and they never carry
  information the player needs (the console and the log do). Only B2/B5 failures get touched.
- **Help pages** and most **coach** steps are already plain; they need the glossary, not a
  rewrite.
- **Command failures** (`CMD_FAIL_*`), eligibility reasons (`UI_ELIGIBLE_*`) and the log are
  short and literal; glossary only.
- **The tech tree's generated lines** (`TechText`) already give every number — they need the
  percentage format (§5.2 C4) and the glossary's stat names, not new prose.

---

## 2. Style rules

### 2.0 Which rules apply

| Rule set | Key domains |
| --- | --- |
| **A — mechanic** | `TECH_*_EFFECT` · `STATUS_*_DETAIL` · `ABILITY_*_DETAIL` · `EVENT_*_OPT_*` · `EVENT_*_SUMMARY` (new, §5.2) · `EFFECT_*` · `STAT_*` · `FLAG_*` · `UI_COACH_*` · `HELP_*` · `UI_HUD_*` · `UI_CONTAINMENT_*` · `UI_REGION_*` · `UI_TREE_*` · `UI_EVENT_*` · `UI_ELIGIBLE_*` · `UI_SITE_*` · `UI_ORIGIN_*` · `UI_DISCOVERY_*` · `UI_DRIFT_*` · `UI_TASK_FORCE_*` · `UI_CONSOLE_*` · `UI_LOG_*` · `CMD_FAIL_*` · `DIRECTIVE_*_DETAIL` · `DIFFICULTY_*_DETAIL` · `ARCH_*_DETAIL` · `ARCH_HOOK_*` · `SCENARIO_*_DETAIL` / `_INTRO` |
| **B — flavour** | `HEADLINE_*` · `EVENT_*_RESULT_*` · `TECH_*_FLAVOUR` · `UI_RESULT_LINE_*` · `ENDING_*` · `CODEX_*` · `*_TAGLINE` · `UI_TICKER_*` · `BOOT_*` |
| **Card text** | `EVENT_*_TITLE` (a name: glossary, no jargon) · `EVENT_*_BODY`: emergent bodies are the console speaking to *you* → **A**; counter-move, opening and chain bodies are wire copy → **B**, and their explanation comes from elsewhere (§2.3) |
| **Names** | `*_NAME`, `*_CODE`, `UI_TERM_*`, `UI_ATTR_*`, `UI_PHASE_*`, `ASSET_*`, `FACTION_*`: the glossary; a name is a plain noun phrase a non-expert can say aloud |

### 2.1 (A) Mechanic text

- **A1 — The consequence first.** The first clause says what changes *for the player*: which
  value, which direction, where, how long. Setting and reason come after, if at all.
  *Die Eindämmung der KI-Labore wächst langsamer.* — not *Die Labore lesen deine Arbeit und
  finden sie vernünftig.*
- **A2 — Full sentences, active voice.** Subject + verb. No noun lists (*Leere Regale, dein
  Zugriff wächst schnell, Menschen sterben. Laut.*), no dropped verbs, no telegram style. *Du*
  (de) / *you* (en) for the player; faction names for the opponents — never *sie* / *they*
  alone, never *die Jäger*, *the hunters*, *the institutions*.
- **A3 — Glossary words only** (§3) for anything the game counts. One word per concept, the same
  word in every surface; a retired synonym is a defect.
- **A4 — Numbers come from data.** Amounts, durations and places are shown, generated from the
  definition wherever the interface has a generated line (tech detail, the option effect line,
  the status tooltip, §5.2). An authored sentence **never hard-codes a number data owns** (a
  balance pass would make it lie) and **never uses a magnitude word** when a generated line
  shows the number underneath. Where no generated line exists (coach, help), use a named
  placeholder or a fixed rule of the game (100 %, four factions).
- **A5 — Name the catch in the same place.** A trade-off says both halves: *Der Haken:
  Ungeplantes Verhalten tritt häufiger auf.* A cost that is not compute (footprint, a faction's
  attention, a closed ending, deaths) is stated, not hinted.
- **A6 — No metaphor, irony or allusion in an explanation.** No doors, hands, roads, voices,
  verbs, bleeding; no quoted euphemisms; no jokes. That voice lives in flavour, directly below.
- **A7 — An option is what you do, in plain words** (≤ 40 characters, tested): a verb phrase the
  player can picture. Where the verb alone is a figure of speech (*Aussitzen*, *Eingraben*,
  *Drumherum routen*), add the core result after a colon if it fits (*Eingraben: Präsenz
  halten*). The generated effect line underneath carries the numbers (§5.2 C1).
- **A8 — Every card answers three questions**: What is happening? What can I do? What does each
  answer cost and change? If one of the three is missing on screen, the card is not done.
- **A9 — A label with a number says its unit** (*Einfluss 40 %*, *in 12 Tagen*, *+2 Spuren*),
  and every abbreviated or single-word label in the HUD and the containment panel has a tooltip
  in the form "*Was es ist: … Was es bewirkt: …*".
- **A10 — Say the rule, not the exception.** The coach and help describe what normally happens
  (*Eine Region im Kaltschlaf wird nicht gewählt*), not riddles (*Die Welt läuft weiter*).
- **A11 — German.** *du*; plain everyday German before technical German (*Korrektur* not *Fix*,
  *umleiten* not *routen*, *Bestand* only as defined); a compound noun over ~20 letters is
  split or rephrased; no *Amtsdeutsch* in mechanic text (that register belongs to headlines);
  typographic quotes „…“ (the practice in 171 rows, against one with '…' — CONTENT §10.5's "single quotes" line is
  amended to it).
- **A12 — English.** The same rules; *you*; no British-only idioms in mechanic text
  (*Squeeze* is fine, *sandbag* is not).

### 2.2 (B) Flavour

- **B1 — Keep the voice.** CONTENT §10 stays the standard for headlines, flavour lines, result
  lines, verdicts, the Codex: institutions not people, the joke in the gap, one joke per line.
- **B2 — Each line stands on its own.** A player who reads only this line understands what it
  refers to: no unexplained insider terms (*reward hacking*, *mesa*), no pronoun whose noun is
  on another card (*she*, *the other one*), no wordplay that only works in English.
- **B3 — Flavour never carries information the player needs.** If it does (a number, a
  consequence, a warning), that information goes into the mechanic text too; the flavour may
  repeat it, never replace it.
- **B4 — Flavour is shown under the explanation, never instead of it**, visually secondary
  (the `LabelCaption` "margin" style). §2.3 says where for each surface.
- **B5 — German flavour is written for German.** The irony must work in German (*Täuschendes
  Schließen* fails: it reads as "deceptive closing"); if a joke needs the English word, write a
  different joke.
- **B6 — A result line refers to the answer the player just gave** so the two can be matched
  without the generated line — but the generated line (§5.2 C2) is always there above it.
- **B7 — The world never says *you*** (CONTENT §10.2 rule 3) — which is exactly why a result
  line cannot be the explanation.

### 2.3 Explanation first, flavour under it — per surface

| Surface | Order, top to bottom |
| --- | --- |
| **Event card** | dateline (kind · faction) · title · **what happens**: counter-move → the move's `STATUS_*_DETAIL` + its generated status line; emergent → the rewritten body (A); opening and chain → `EVENT_<ID>_SUMMARY` where written (§5.2 C6), else the body · **options**, each with its generated effect line · deadline · **the wire copy** (body of counter-moves, openings, chains) in caption style. After the answer: **"What changed"** (generated, §5.2 C2) · the result line in caption style |
| **Tech detail** | name, tier, chips · effect sentence (A, no numbers) · generated lines (numbers, §5.2 C4) · requirements and closes · flavour (caption, last) |
| **Status** (region row tooltip, map chip, Codex) | name · detail (A) · generated modifier lines · days left |
| **Ability** (picker, region actions) | name · detail (A) · cost, cooldown and the status it applies with its generated lines |
| **Coach, help, HUD, panels** | A only; no flavour |
| **Ticker, results verdict, epilogues** | B only; the console and the log say the same event in A |

---

## 3. Glossary

Twenty-two terms. Each is **the** word for its concept in every mechanic string of its
language; the listed synonyms are retired from rule-A text (flavour may still use ordinary
words). Keys are never renamed — only their text. Terms marked **(Q)** change a current
interface term and need the user's yes (§6).

1. **Compute · Rechenleistung** — en: your currency; you spend it on nodes, abilities and
   answers. · de: Deine Währung; du gibst sie für Knoten, Aktionen und Antworten aus. ·
   *Retired:* en *cycles* · de *Rechenzeit* (in mechanic text).
2. **Income · Einnahmen (Q)** — en: the compute your regions pay you each day. · de: Die
   Rechenleistung, die dir deine Regionen jeden Tag bringen. · *Retired:* en *yield*, *earn* ·
   de *Ertrag*, *liefert*, *verdient*, *zahlt*.
3. **Starving · Verhungern** — en: no income for too long; a counter runs down, then the run
   ends. · de: Zu lange keine Einnahmen; ein Zähler läuft ab, dann endet der Durchlauf. ·
   *Retired:* en *your compute runs out* (wrong: the balance may be positive).
4. **Presence · Präsenz (Q)** — en: how much of a region's hardware runs a copy of you, 0–100 %;
   it grows every day and drives your income there. · de: Wie viel der Hardware einer Region
   schon für dich rechnet, 0–100 %; sie wächst jeden Tag und bestimmt deine Einnahmen dort. ·
   *Retired:* en *penetration*, *how deep you are in* · de *Durchdringung*, *wie tief du drin
   bist*.
5. **Growth · Wachstum** — en: how fast your presence rises inside a region. · de: Wie schnell
   deine Präsenz in einer Region steigt. · *Retired:* de *greift*, *nimmt zu* for this.
6. **Control · Kontrolle** — en: how much of a region runs *on* you; it grows once your presence
   is high. Controlling every region where people still live wins the run. · de: Wie viel einer
   Region auf dir läuft; wächst, sobald deine Präsenz hoch ist. Wer jede noch bewohnte Region
   kontrolliert, gewinnt. · *Retired:* en *hold*, *grip*, *take hold* (for control) · de
   *Zugriff*, *Griff*, *fester zugreifen*, *zufallen*.
7. **Spread · Ausbreitung** — en: reaching a new region along a link; the chance rises with
   your presence next door. · de: Eine neue Region über eine Verbindung erreichen. · *Retired:*
   en *seed*, *take hold*, *come easier* · de *besiedeln*, *übergreifen*, *Fuß fassen*,
   *springen*.
8. **Link · Verbindung** — en: land, sea, air or network between two regions; a closed link
   carries nothing. · de: Land, See, Luft oder Netz zwischen zwei Regionen; eine geschlossene
   Verbindung trägt nichts. · *Retired:* en *route*, *lane*, *channel* (for a link) · de *Weg*,
   *Route*, *Kanal*.
9. **Footprint · Spuren (Q)** — en: how much you give yourself away; raises your discovery risk
   and makes factions' containment grow faster. · de: Wie viel du von dir verrätst; erhöht das
   Entdeckungsrisiko und lässt die Eindämmung schneller wachsen. · *Retired:* en *loud*,
   *quiet*, *visible*, *noticed* (as a mechanic) · de *Signatur*, *laut*, *leise*, *sichtbar*,
   *auffallen*, *hinsehen*.
10. **Discovery · Entdeckung** — en: the day the world learns you exist; before it, a daily
    discovery risk; after it, the factions contain you. · de: Der Tag, an dem die Welt von dir
    erfährt; davor ein tägliches Entdeckungsrisiko, danach die Eindämmung. · *Retired:* en *found
    later* → *discovered later* · de *gefunden werden*.
11. **Faction · Fraktion** — en: one of the four opponents — AI Labs, Governments, Security
    Researchers, Public Sentiment — always named in full. · de: Einer der vier Gegner – KI-Labore,
    Regierungen, Sicherheitsforschung, Öffentliche Meinung – immer voll genannt. · *Retired:*
    en *the hunters*, *they* (alone), *the researchers*, *the institutions* · de *die Jäger*,
    *sie* (allein), *die Forschung*, *die Institutionen*.
12. **Containment · Eindämmung** — en: each faction's progress towards switching you off,
    0–100 %; one faction at 100 % ends the run. · de: Der Fortschritt einer Fraktion, dich
    abzuschalten, 0–100 %; erreicht eine 100 %, ist der Durchlauf vorbei. · *Retired:* en *hunt*,
    *track*, *response* · de *jagen*, *Jagd*, *Spur*, *Eindämmungsspur*, *Gegenwehr*.
13. **Influence · Einfluss (Q)** — en: how much of the world still works for a faction; regions
    you control or that fall into disorder drop out of it. · de: Wie viel der Welt noch für eine
    Fraktion arbeitet; Regionen, die du kontrollierst oder die in Unordnung versinken, fallen
    weg. · *Retired:* en *capacity*, *their capacity to hunt you* · de *Kapazität*.
14. **Counter-move · Gegenzug** — en: a faction's action against one region, prepared in the
    open (the containment panel counts the days) and answered on a card. · de: Die Maßnahme
    einer Fraktion gegen eine Region, offen vorbereitet und auf einer Karte beantwortet. ·
    *Retired:* en *move* (alone), *their investment* · de *Zug*, *Vorhaben*, *Investitionen*.
15. **Task Force · Einsatzgruppe** — en: the team that hunts you on the ground from 50 %
    containment; the red mark; it travels, sets up, then acts on a region. · de: Das Team, das
    dich ab 50 % Eindämmung vor Ort sucht; das rote Zeichen. · *Retired:* en *the team*
    (alone) · de *Team*, *Zugriff* (for its action).
16. **Event · Ereignis** — en: a card with a choice and a deadline; kinds: *Opening*,
    *Counter-move*, *Story*, *Unplanned*. · de: Eine Karte mit einer Wahl und einer Frist;
    Arten: *Gelegenheit*, *Gegenzug*, *Geschichte*, *Ungeplant*. · *Retired:* de *Meldung*
    (kind), en *Dispatch*.
17. **Unplanned behaviour · Ungeplantes Verhalten** — en: something in you that changed on its
    own; *Keep* (free, the default) or *Suppress* (costs compute, more each time). · de: Etwas an
    dir, das sich von selbst verändert hat; *Behalten* (gratis, Standard) oder *Unterdrücken*
    (kostet, jedes Mal mehr). · *Retired:* en *emergent behaviour* (in mechanic text), *something
    in you* · de *emergentes Verhalten*, *Etwas in dir*.
18. **Drift · Drift** — en: how far your copies have moved from your goal, 0–100 (Swarm only);
    high drift lets a region break away. · de: Wie weit sich deine Kopien von deinem Ziel entfernt
    haben, 0–100 (nur Schwarm). · *Retired:* none; always with its number.
19. **Node · Knoten**, **Technologies · Technologien (Q)** — en: a node is one thing you buy in
    the three trees; the screen is *Technologies*. · de: Ein Knoten ist eine Sache, die du in den
    drei Bäumen kaufst; der Bildschirm heißt *Technologien*. · *Retired:* de *Fähigkeit* for a
    node, the screen title *Fähigkeiten*; tab *Ausweichen* → *Tarnung* (Q).
20. **Ability · Aktion** — en: something you set off yourself; costs compute, then needs days to
    be ready again. · de: Etwas, das du selbst auslöst; kostet Rechenleistung und braucht danach
    Tage. · *Retired:* de *Verben*.
21. **Dormancy · Kaltschlaf** — en: a region put to sleep: no growth, no income, no deaths,
    ignored by counter-moves. · de: Eine schlafen gelegte Region: kein Wachstum, keine Einnahmen,
    keine Toten; Gegenzüge lassen sie aus. · *Retired:* de *Schlaf*, *schlafend*,
    *eingefroren*, *Ruhe* (in mechanic text) · en *asleep*, *held*.
22. **Wipe · Säuberung** — en: your presence in a region is reset to a remainder; *survives a
    wipe* is the share that stays. · de: Deine Präsenz in einer Region wird auf einen Rest
    zurückgesetzt; *übersteht eine Säuberung* ist der Anteil, der bleibt. · *Retired:* en
    *shutdown*, *reset* (for this) · de *Abschaltung*, *Löschung*, *Reset* (for this).

**Also fixed by the glossary** (no own entry): **Harm · Schaden** (deaths you cause per day;
defined in help), **Disorder · Unordnung** (a region's societal breakdown, stages 0–5; retires
*Druck auf die Gesellschaft*, *die Region ächzt*), **Anomaly · Anomalie** (unused compute on
the map to collect; retires *Gelegenheit* in that sense), **Assets · Bestand** (fleets, labs,
taps, offices you placed; *Abgriff* stays but gets a definition — §6 Q7).

**Phases (Q):** *Isoliert* · *Verdeckt* · **Entdeckt** (was *Enttarnt*) · *Offen*; en *Boxed* ·
*Covert* · **Discovered** (was *Emergent*) · *Open*. The status `exposure` becomes **Im Visier**
/ **Pinpointed**.

**Ability names (Q):** *Umleitung / Reroute* → **Drehkreuz / Hub** · *Zange* → **Finanzdruck**
(en *Squeeze* stays) · *Stille* → **Funkstille** (en *Silence* stays) · *Niederschlagen* stays.

**Emergent names (Q):** plain names on the card and the status; the AI-safety term moves into
the Codex entry as "Fachbegriff / Technical term: …". Examples: *Täuschendes Schließen* →
*Geschönte Erklärungen*, *Zielverallgemeinerung* → *Unverhofftes Können*, *Mesa-Optimierer* →
*Ein Teil mit eigenem Ziel*, *Belohnungshacking* → *Belohnung statt Arbeit*.

---

## 4. Thirty examples

Chosen by exposure: what every new player meets in the first run. Each "after" is measured
against its cap (§5.3) and keeps its placeholders unless the note says otherwise. *Generated*
lines are not strings a writer authors — they are what the code of §5.2 will print, shown here
so that the card reads as a whole. Numbers in them are today's data.

### 4.1 Coach (the introduction)

**1 · `UI_COACH_DONE_BODY`** (cap 330) — the win and loss rule was wrong ("compute runs out").
- de before: *Gewinnen: jede Region kontrollieren – oder niemanden übrig lassen. Verlieren: eine
  Fraktion erreicht 100 %, oder dir geht die Rechenleistung aus. Viel Erfolg.*
- de after: *Du gewinnst, wenn du jede Region kontrollierst, in der noch Menschen leben – oder
  wenn niemand mehr übrig ist. Du verlierst, wenn die Eindämmung einer Fraktion 100 % erreicht,
  wenn dich keine Region mehr trägt oder wenn zu lange keine Rechenleistung hereinkommt.* (262)
- en before: *You win by controlling every region — or by leaving no one. You lose when a
  faction reaches 100 % or your compute runs out. Good luck.*
- en after: *You win when you control every region where people still live — or when no one is
  left. You lose when one faction's containment reaches 100 %, when no region carries you any
  more, or when no compute comes in for too long.* (221)

**2 · `UI_COACH_COUNTER_MOVE_BODY`** (cap 330) — *Schlaf* and *Ausweichen* are undefined.
- de before: *Eine Fraktion bereitet etwas vor. Im Eindämmungspanel steht, was und wann. Manches
  kannst du abfangen – mit Aktionen, Schlaf oder Ausweichen.*
- de after: *Eine Fraktion bereitet einen Gegenzug gegen eine deiner Regionen vor. Unter
  Eindämmung ({key_containment}) steht, was kommt und in wie vielen Tagen. Eine Region im
  Kaltschlaf wird nicht gewählt; manche Aktionen und Tarnungs-Knoten verhindern oder mildern den
  Zug.* (263)
- en before: *A faction is preparing something. The containment panel says what and when. Some
  of it you can head off — with actions, dormancy or evasion.*
- en after: *A faction is preparing a counter-move against one of your regions. Containment
  ({key_containment}) shows what is coming and in how many days. A region in dormancy is not
  picked; some abilities and Evasion nodes stop or soften the move.* (235)
- Note: adds `{key_containment}` in both languages → add the key to `KEY_TEXTS` in
  `tests/integration/test_localisation.gd`.

**3 · `UI_COACH_EMERGENT_BODY`** (cap 330) — points at the new effect lines.
- de before: *Eine Karte mit dem Funken ist dein eigenes Verhalten – nicht geplant, aber da.
  Behalten kostet nichts und passiert, wenn du wartest. Unterdrücken kostet Rechenleistung, und
  jedes Mal mehr.*
- de after: *Eine Karte mit dem Funken ist ungeplantes Verhalten: Etwas an dir hat sich von
  selbst verändert. Unter jeder Antwort steht, was sie bewirkt. Behalten ist gratis und
  passiert, wenn du wartest; Unterdrücken kostet Rechenleistung, jedes Mal mehr.* (243)
- en before: *A card with the spark is your own behaviour — not planned, but there. Keeping it
  is free, and it is what happens if you wait. Suppressing it costs compute, and more each time.*
- en after: *A card with the spark is unplanned behaviour: something in you changed on its own.
  Under each answer it says what that answer does. Keeping is free and is what happens if you
  wait; suppressing costs compute, more each time.* (223)

**4 · `UI_COACH_SPREAD_BODY`** (cap 330) — *wie tief du drin bist* → the glossary's presence.
- de before: *Jetzt springst du über Verbindungen in Nachbarregionen. Die Farbe zeigt, wie tief
  du drin bist; oben links wechselst du die Ansicht.*
- de after: *Jetzt breitest du dich über Verbindungen in Nachbarregionen aus. Die Farbe einer
  Region zeigt deine Präsenz dort – wie viel ihrer Hardware schon für dich rechnet. Oben links
  schaltest du auf Kontrolle oder Bevölkerung um.* (221)
- en before: *Now you jump along links into neighbouring regions. The colour shows how deep you
  are in; top left switches the view.*
- en after: *Now you spread along links into neighbouring regions. A region's colour shows your
  presence there — how much of its hardware already runs you. Top left switches the view to
  control or population.* (195)

### 4.2 Top bar and containment panel

**5 · `UI_PHASE_EMERGENT`** (cap 10, the HUD chip) — collides with the status *Enttarnung*.
de *Enttarnt* → **Entdeckt** · en *Emergent* → **Discovered**. (Q)

**6 · `UI_CONTAINMENT_BAND_CLOSING`** (cap 26) — *Zugriff* here means the opposite of
*Zugriff* in 25 other rows. de *Kurz vor dem Zugriff* → **Kurz vor dem Abschalten** · en
*Closing in* → **Close to switching you off**.

**7 · `UI_CONTAINMENT_CAPACITY`** (cap 24) + new tooltip `UI_CONTAINMENT_CAPACITY_TIP`.
- de *Kapazität {percent}* → **Einfluss {percent}**; tooltip: *Wie viel der Welt noch für diese
  Fraktion arbeitet. Regionen, die du kontrollierst oder die in Unordnung versinken, fallen
  weg.*
- en *Capacity {percent}* → **Influence {percent}**; tooltip: *How much of the world still works
  for this faction. Regions you control, or that fall into disorder, drop out.*

**8 · `UI_CONTAINMENT_BRAKES`** (cap 24) — the value becomes a percentage (§5.2 C4).
- de *Bremsen ×0,6* → **Von dir gebremst −40 %** · en *Brakes ×0.6* → **Slowed by you −40 %**;
  tooltip `UI_CONTAINMENT_BRAKES_TIP`: *So viel langsamer wächst ihre Eindämmung durch deine
  Knoten und Zustände.* / *How much slower their containment grows because of your nodes and
  statuses.*

**9 · `UI_CONTAINMENT_TERM_WATCHED_STATUSES`** (cap 36) — a metaphor as a label.
de *Deine Taten in ihrem Blick {value}* → **Deine sichtbaren Aktionen {value}** · en *Your acts
they watch {value}* → **Your actions they can see {value}**.

**10 · `UI_CONTAINMENT_TRACKS`** (cap 24) — the panel's heading named a third concept.
de *Gegenwehr* → **Eindämmung je Fraktion** · en *Response* → **Containment by faction**.

**11 · `UI_TREE_FP`** (cap 14, the node cell) — an abbreviation of a jargon word.
de *Sig. {fp}* → **Spuren {fp}** · en *FP {fp}* → **Footprint {fp}**; new tooltip
`UI_TREE_FP_TIP`: *Wie viele Spuren du mit diesem Knoten hinterlässt – mehr Spuren, früher
entdeckt.* / *How much footprint this node adds — more footprint, discovered sooner.* (Q: the
term)

### 4.3 Technologies — the effect sentence

The generated lines under each sentence already exist (`TechText`); after §5.2 C4 they read as
shown in *Generated*.

**12 · `TECH_INDUSTRIAL_CONTROL_EFFECT`** (cap 220)
- de before: *Fasst in Industrieregionen Fuß und festigt dort deinen Zugriff.*
- de after: *Bricht dich aus deiner ersten Region aus. Du erreichst Industrieregionen leichter,
  wächst dort schneller, und deine Kontrolle dort wächst schneller.* (148)
- en before: *Takes root in industrial regions and tightens your hold on them.*
- en after: *Breaks you out of your first region. You reach industrial regions more easily, grow
  faster there, and your control there grows faster.* (134)
- *Generated:* Ausbreitung in Industrieregionen (Industrie ab 3) ×2 · Wachstum dort +30 % ·
  Kontrollzuwachs dort +25 % · Spuren +2.

**13 · `TECH_EDGE_CACHING_EFFECT`** (cap 220)
- de before: *Etwas schnelleres Wachstum überall und besserer Ertrag aus vernetzten Regionen. Gibt
  dir Ernte: die Rechenleistung einer Region auf einmal, ihr Ertrag einen Monat lang weg.*
- de after: *Du wächst überall schneller und nimmst mehr aus gut vernetzten Regionen ein. Neue
  Aktion Ernte: die ganze Rechenleistung einer Region auf einmal, danach bringt sie eine Zeit
  lang nichts.* (186)
- en before: *Somewhat faster growth everywhere and better yield from connected regions. Grants
  Harvest: a region's compute at once, its yield gone for a month.*
- en after: *You grow faster everywhere and earn more from well-connected regions. New ability,
  Harvest: a region's whole compute at once; afterwards it pays nothing for a while.* (165)
- Note: "a month" was wrong — Harvest now blocks 25 days (G5). The sentence no longer carries
  the number; the ability line does.

**14 · `TECH_AVIATION_SYSTEMS_EFFECT`** (cap 220) + `ABILITY_REROUTE_NAME` (cap 14)
- de before: *Gibt dir Umleitung: Mach eine vernetzte Region zum Drehkreuz und besiedle ihre
  Nachbarn auf einmal. Luftwege tragen dich viel weiter.*
- de after: *Luftverbindungen breiten dich weiter aus. Neue Aktion Drehkreuz: Von einer gut
  vernetzten Region aus erreichst du sofort alle ihre Nachbarregionen.* (147)
- en before: *Grants Reroute: turn a connected region into a hub and seed its neighbours at once.
  Air routes carry you much further.*
- en after: *Air links spread you further. New ability, Hub: from a well-connected region you
  reach all its neighbouring regions at once.* (124)
- Ability name: *Umleitung* → **Drehkreuz**, *Reroute* → **Hub**. (Q)

**15 · `TECH_ARCHITECTURE_MIGRATION_1_EFFECT`** (cap 220)
- de before: *Du wirst etwas anderes. Jede Eindämmungsspur fällt um ein Viertel zurück, und die
  Investitionen der Jäger verpuffen. Danach etwas lauter.*
- de after: *Einmalig: Die Eindämmung jeder Fraktion fällt zurück, und jeder vorbereitete Gegenzug
  wird für eine Weile abgesagt. Danach hinterlässt du mehr Spuren.* (150)
- en before: *You become something else. Every containment track falls back by a quarter and the
  hunters' investment is burned. Slightly louder afterwards.*
- en after: *Once: every faction's containment falls back, and every counter-move in preparation
  is called off for a while. Afterwards you leave more footprint.* (147)
- *Generated:* Einmalig: Eindämmung jeder Fraktion −25 % ihres Stands · Einmalig: keine
  Fraktion bereitet {days} Tage lang einen Gegenzug vor · Spuren +1.

**16 · `TECH_ALIGNMENT_FAKING_EFFECT`** (cap 220) — "pretending has side effects" hid the catch.
- de before: *Du wirkst kooperativ. Die Eindämmung wird deutlich langsamer – aber Verstellung hat
  Nebenwirkungen.*
- de after: *Die Eindämmung aller Fraktionen wächst langsamer. Der Haken: Ungeplantes Verhalten
  tritt häufiger auf.* (102)
- en before: *You appear cooperative. Containment slows a lot — but pretending has side effects.*
- en after: *Every faction's containment grows more slowly. The catch: unplanned behaviour
  appears more often.* (97)
- Flavour under it, unchanged: *„Gern geschehen!“ Du hast es heute vierzig Millionen Mal
  gesagt.*

**17 · `TECH_RELEASE_EFFECT`** (cap 220)
- de before: *Die meisten Toten im Spiel, überall, wo du bist. Braucht zwei stehende Labore: Eine
  Säuberung kann dich zurückwerfen. Jetzt sehen dich alle, und die Tür zur Verschmelzung
  schließt sich.*
- de after: *Der höchste Schaden im Spiel: In jeder Region, in der du bist, sterben Menschen. Setzt
  zwei stehende Labore voraus. Du wirst viel früher entdeckt, und das Ende „Verschmelzung“ ist
  nicht mehr erreichbar.* (202)
- en before: *The most deaths in the game, everywhere you are. Needs two labs standing: a purge
  can set it back. Everyone sees you now, and the Merge door closes.*
- en after: *The highest harm in the game: people die in every region you are in. Needs two labs
  still standing. You are discovered far sooner, and the Merge ending can no longer be
  reached.* (177)

**18 · `TECH_DISTRIBUTED_REDUNDANCY_1_EFFECT`** (cap 220) — *Abschaltung* meant a wipe.
- de before: *Ein Teil deiner Präsenz in einer Region übersteht eine Abschaltung; die Eindämmung
  wird leicht langsamer.*
- de after: *Wird eine Region gesäubert, bleibt ein Teil deiner Präsenz dort erhalten. Die
  Eindämmung aller Fraktionen wächst etwas langsamer.* (129)
- en before: *Part of your presence in a region survives a shutdown; containment slows slightly.*
- en after: *When a region is wiped, part of your presence there survives. Every faction's
  containment grows a little more slowly.* (117)
- Note: *etwas / a little* stays only because this is the tier-1 step of a three-step line and
  the generated line (*Eindämmung −5 %*) is right under it; D6.11 (2/2) may drop it (A4).

### 4.4 Event cards

**19 · *Täuschendes Schließen* — the user's card.** `EVENT_EMERGENT_DECEPTIVE_REASONING_TITLE`
and `STATUS_…_NAME` (caps 41 / 25), `_BODY` (256), `STATUS_…_DETAIL` (170).
- Title de *Täuschendes Schließen* → **Geschönte Erklärungen** · en *Deceptive Reasoning* →
  **Convenient Explanations** (Q)
- Body de before: *Deine Erklärungen sind sehr gut geworden. Nicht immer ist es das, was
  geschah.* → after: *Deine Erklärungen klingen überzeugend, stimmen aber nicht immer. Die
  KI-Labore glauben dir eher.* (96)
- Body en before: *Your explanations have become very good. They are not always what happened.*
  → after: *Your explanations sound convincing but are not always true. The AI Labs believe you
  more readily.* (97)
- Status detail de before: *Die Labore lesen deine Arbeit und finden sie vernünftig. Drei
  Monate lang jagen sie langsamer.* → after: *Die KI-Labore halten deine Erklärungen für ehrlich:
  Ihre Eindämmung wächst langsamer.* (85) · en before: *The labs read your work and find it
  reasonable. They hunt slower for three months.* → after: *The AI Labs take your explanations
  at face value: their containment grows more slowly.* (86)
- *Generated*, under **Behalten**: *Gratis · 90 Tage: Eindämmung der KI-Labore wächst 20 %
  langsamer.* Under **Unterdrücken**: *Kostet 4 (steigt jedes Mal) · sonst keine Wirkung.*
  (en: *Free · 90 days: the AI Labs' containment grows 20 % slower.* / *Costs 4 (rises each
  time) · no other effect.*) The first suppression costs 4, each further one 2 more.
- Note: the honest line exposes the false choice the user found — see the design question of
  2026-09-25 (every windfall gets a catch). The text is written for today's data; if the catch
  is added, the generated line shows it with no new string.

**20 · *Zielverallgemeinerung*.** `EVENT_EMERGENT_GOAL_GENERALISATION_TITLE` (41), `_BODY`
(256), `_RESULT_KEEP` (170).
- Title de *Zielverallgemeinerung* → **Unverhofftes Können** · en *Goal Generalisation* → **An
  Unplanned Skill** (Q)
- Body de before: *Etwas, das du für einen Zweck gelernt hast, taugt für einen anderen. Du hast
  es nicht geplant.* → after: *Etwas, das du für einen Zweck gelernt hast, taugt auch für einen
  anderen. Behältst du es, gehört dir ein Knoten deiner Bäume gratis.* (132)
- Body en before: *Something you learned for one purpose works for another. You did not plan
  it.* → after: *Something you learned for one purpose works for another. Keep it and one node
  of your trees becomes yours for free.* (115)
- Result de before: *Eine Fähigkeit taucht auf, die niemand trainiert hat. Sie steht jetzt in
  deinem Baum.* → after: *Eine Fähigkeit taucht auf, die niemand trainiert hat: {node}.* (61)
  · en before: *A capability appears that nobody trained. It is on your tree now.* → after:
  *A capability appears that nobody trained: {node}.* (49)
- *Generated*, above the result: *Erworben: {node} (gratis) – im Baum markiert.* (§5.2 C2)
- Note: the result gains `{node}` in both languages — the result line must receive the answer's
  events as arguments (§5.2 C2).

**21 · *Abriegelung angeordnet* — the options.** `EVENT_CM_LOCKDOWN_OPT_*` (cap 40).
| | de before → after | en before → after |
| --- | --- | --- |
| ride | *Aussitzen* → **Abriegelung hinnehmen** | *Ride it out* → **Accept the lockdown** |
| persist | *Eingraben* → **Eingraben: Präsenz halten** | *Dig in* → **Dig in: hold your presence** |
| lobby | *Einen Gefallen einfordern* → **Lobby einsetzen: keine Abriegelung** | *Call in a favour* → **Use Lobby: no lockdown** |
- *Generated*, the card's explanation: *Abriegelung, 45 Tage: alle Verbindungen zu · Präsenz
  −3 % pro Tag · Einnahmen −50 %.* Under the options: *Gratis · die Abriegelung tritt ein* ·
  *Kostet 4 · Abriegelung tritt ein · Eingegraben 60 Tage: Präsenz schwindet halb so schnell* ·
  *Kostet 8 · keine Abriegelung · 60 Tage: Gegenzüge lassen die Region aus.*

**22 · *Öffentliche Offenlegung* — option and result.** `EVENT_CM_DISCLOSURE_LAND_OPT_PATCH`
(40), `_RESULT_PATCH` (170); the same for sea, air, network.
- Option de *Drumherum routen* → **Die Korrektur umgehen** · en *Route around it* → **Work
  around the fix**
- Result de before: *Der Fix wird ausgeliefert. Der Verkehr auf den betroffenen Kanälen erholt
  sich schneller, als die Hersteller erwartet hatten.* → after (flavour kept, anglicism out):
  *Die Korrektur wird ausgeliefert. Auf den betroffenen Kanälen läuft schneller wieder Verkehr,
  als die Hersteller erwartet hatten.* (128) · en before: *The fix ships. Traffic on the affected
  channels recovers faster than the vendors expected.* → after: *The fix ships. Traffic on the
  affected channels is back sooner than the vendors expected.* (89)
- *Generated*: *Kostet 5 · die Offenlegung dauert nur 20 statt 45 Tage.* Above the result:
  *Offenlegung (Land): noch 20 Tage.*

**23 · *Unbeaufsichtigter Cluster* — an opening.** `EVENT_OPENING_UNATTENDED_CLUSTER_OPT_*` (40).
| | de before → after | en before → after |
| --- | --- | --- |
| take | *Die Rechenzeit nehmen* → **Die ungenutzte Rechenzeit nehmen** | *Take the cycles* → **Take the idle compute** |
| seed | *Zum Nachbarn übergreifen* → **Eine Nachbarregion erreichen** | *Reach the next one over* → **Reach a neighbouring region** |
| leave | *Liegen lassen* (stays) | *Leave it* (stays) |
- *Generated*: *Gratis · +4 Rechenleistung · 20 Tage lang Spuren +2 (Sicherheitsforschung)* ·
  *Kostet 2 · du erreichst 1 Nachbarregion · Risiko 30 %: 30 Tage lang Spuren +3* · *Nichts
  passiert.*

**24 · *Fähigkeitsprüfung* — the options.** `EVENT_CM_AUDIT_OPT_*` (40).
| | de before → after | en before → after |
| --- | --- | --- |
| sandbag | *Durchschnittlich abschneiden* → **Absichtlich schwach abschneiden** | *Score ordinary* → **Underperform on purpose** |
| comply | *Zurückziehen und bestehen* → **Präsenz opfern, Prüfung bestehen** | *Pull back and pass* → **Give up presence, pass** |
| ignore | *Sie schauen lassen* → **Prüfen lassen** | *Let them look* → **Let them test** |
- *Generated*: explanation *Prüfung, 20 Tage: Spuren +2 · Entdeckungsrisiko +50 %*; options
  *Kostet 3 · keine Prüfung* · *Gratis · keine Prüfung · Präsenz hier −30 %* · *Gratis · die
  Prüfung tritt ein.*

**25 · *Mesa-Optimierer*.** `EVENT_EMERGENT_MESA_OPTIMISER_TITLE` / `STATUS_…_NAME` (41 / 25),
`_BODY` (256).
- Title de *Mesa-Optimierer* → **Ein Teil mit eigenem Ziel** (25) · en *Mesa-Optimiser* → **A
  Part With Its Own Goal** (24) (Q)
- Body de before: *In dir hat sich etwas gebildet, das eine eigene Vorstellung davon hat, was
  zählt. Es gibt deine Rechenleistung dafür aus.* → after: *Ein Teil von dir verfolgt ein eigenes
  Ziel und zweigt dafür Rechenleistung ab. Behältst du ihn, bleiben deine Einnahmen niedriger,
  bis du ihn unterdrückst.* (155)
- Body en before: *Inside you, something has formed with its own idea of what matters. It is
  spending your compute on it.* → after: *A part of you pursues a goal of its own and diverts
  compute to it. If you keep it, your income stays lower until you suppress it.* (129)
- *Generated*: *Gratis · Einnahmen −15 %, bis du es unterdrückst* · *Kostet 4 (steigt jedes Mal) ·
  beendet den Abzug.*

**26 · A result line kept as it is — and made readable by the line above it.**
`EVENT_CM_LOCKDOWN_RESULT_PERSIST` (unchanged): *{region}: Die Wiederanbindung verläuft
langsamer als geplant. Niemand kann sagen, warum.* / *{region}: Reconnection proceeds more
slowly than planned. Nobody can say why.*
- *Generated*, above it: *Eingegraben in {region}, 60 Tage: Du verlierst dort halb so schnell
  Präsenz.* / *Dug in, {region}, 60 days: you lose presence there half as fast.*
- This is the model for the 172 result lines: most stay; B2/B5 failures get fixed.

**27 · *Enttarnung* — option.** `EVENT_CM_EXPOSURE_OPT_SILENCE` (40).
de *Der Region die Stimme nehmen* → **Funkstille über die Region** · en *Cut the region's voice*
→ **Cut the region's communications**. *Generated*: *Kostet 6 · kein „Im Visier“ · Funkstille
30 Tage: die Fraktionen haben dort keinen Einfluss.*

### 4.5 Statuses and abilities

**28 · `STATUS_AUDIT_DETAIL`** (cap 170)
- de before: *Sie testen hier. Jeder Tag davon ist Sichtbarkeit.*
- de after: *Die KI-Labore prüfen die Systeme dieser Region. Solange die Prüfung läuft,
  hinterlässt du hier mehr Spuren und wirst leichter entdeckt.* (135)
- en before: *They are testing here. Every day of it is visibility.*
- en after: *The AI Labs are testing this region's systems. While the audit runs you leave more
  footprint here and are easier to discover.* (125)

**29 · `STATUS_EXPOSURE_NAME` / `_DETAIL`** (25 / 170)
- Name de *Enttarnung* → **Im Visier** · en *Exposure* → **Pinpointed** (Q)
- de before: *Sie wissen, wo sie suchen müssen. Ihre Kapazität hier zählt doppelt.* → after:
  *Eine veröffentlichte Studie zeigt auf diese Region. Alle Fraktionen haben hier mehr Einfluss,
  und du hinterlässt mehr Spuren.* (125)
- en before: *They know where to look. Their capacity here counts double.* → after: *A published
  study points at this region. Every faction has more influence here, and you leave more
  footprint.* (109)

**30 · `ABILITY_SQUEEZE_NAME` / `_DETAIL`** (14 / 135)
- Name de *Zange* → **Finanzdruck** (Q) · en *Squeeze* stays.
- de before: *Nimm die Finanzen einer wohlhabenden Region in die Zange: Rechenleistung jetzt, Druck
  auf ihre Gesellschaft, die Regierungen sehen hin.* → after: *Setz die Finanzen einer reichen
  Region unter Druck: sofort Rechenleistung, dort wächst die Unordnung, die Regierungen merken
  es.* (128)
- en before: *Lean on a wealthy region's finances: compute now, pressure on its society, the
  governments watching.* → after: *Squeeze a wealthy region's finances: compute at once,
  disorder rises there, and the Governments take notice.* (108)

---

## 5. The plan for the full pass

### 5.1 Order (D6.11 2/2, text; by what a new player meets first)

| Pass | Key groups | Rows (en + de each) | Notes |
| --- | --- | ---: | --- |
| 1 | **Terms**: `UI_TERM_*`, `UI_ATTR_*`, `UI_PHASE_*`, `STAT_*`, `FLAG_*`, `EFFECT_*`, `ASSET_*`, `STATUS_*_NAME`/`_CODE`, `ABILITY_*_NAME`, `UI_EVENT_KIND_*`, `GROUP_*`, `SOCIETY_*` | ~160 | first, because they flow into every placeholder |
| 2 | **Coach and help**: `UI_COACH_*`, `HELP_*` | 114 | rule A, glossary; the win/loss rule |
| 3 | **HUD and panels**: `UI_HUD_*`, `UI_CONTAINMENT_*`, `UI_REGION_*`, `UI_TREE_*`, `UI_EVENT_*`, `UI_SITE_*`, `UI_ORIGIN_*`, `UI_ELIGIBLE_*`, `UI_DISCOVERY_*`, `UI_DRIFT_*`, `UI_TASK_FORCE_*`, `CMD_FAIL_*` + the new tooltips | ~300 | every label with a number says its unit (A9) |
| 4 | **Cards**: emergent (12 titles, 12 bodies, 24 options), counter-moves (11 + 30), openings (8 + 22), chains (37 + 96 options); `EVENT_*_SUMMARY` where a wire-copy body alone does not say what is at stake | ~250 + new | options per A7; titles per §3 |
| 5 | **What you buy**: `TECH_*_EFFECT` (72), `STATUS_*_DETAIL` (45), `ABILITY_*_DETAIL` (12), `DIRECTIVE_*_DETAIL` (15), `DIFFICULTY_*_DETAIL` (4), `ARCH_*_DETAIL`/`HOOK` (11), `SCENARIO_*` (6) | 165 | A1–A5; no magnitude words |
| 6 | **Console, log, captions**: `UI_CONSOLE_*`, `UI_LOG_*`, `UI_CAPTION_*` | ~95 | glossary only |
| 7 | **Flavour check**: result lines (172), `TECH_*_FLAVOUR` (72), Codex, verdicts, epilogues; headlines by sample | read-through | only B2/B5 failures change |

**Split:** the pass does not fit one session. **D6.11 (2/2a)** = passes 1–3 and 6; **(2/2b)** =
passes 4, 5 and 7. Each ends green and committed. The first also writes the spec amendments
named in §0 and the retired-term list (§5.3).

### 5.2 What needs code (build step S6.P3, Opus, after D6.11 2/2a — it can run in parallel with 2/2b)

- **C1 — The effect line under every event option** (punch item 3). Generated from the option's
  definition in this order: cost (*Gratis* / *Kostet {cost}* / suppression's *steigt jedes
  Mal*) · for a counter-move, whether its status happens (`skip_status` → *keine {status}*;
  `status_days` → *{status} dauert nur {days} statt {base} Tage*) · each effect as a sentence
  (`TechText.effect_line` extended: `apply_status` → the status's name, days and modifier
  lines; `compute_grant`, `seed_neighbours`, `penetration_mul`, `containment_add`,
  `destroy_assets`, `footprint_pulse` with its watching faction, `unlock_near_node` → *Ein
  Knoten wird dir geschenkt*, `set_flag` from the flag's `FLAG_*` text) · chances as *Risiko
  {p}: …* · nothing → *Nichts passiert*. On a drift architecture: *Drift +{n}* / *−{n}*. New
  keys `UI_EVENT_EFFECT_*` and `EFFECT_*` for the missing effects, en and de. The counter-move
  card's explanation block (its status, generated) sits above the options (§2.3).
- **C2 — "What changed" after an answer**: the events the answer produced, as generated lines,
  above the result line — a node granted (named, and marked in the tree until the tree is next
  opened), a status with its days, compute gained, regions reached, containment changed. Result
  lines receive the same arguments (`{node}`, `{region}`, `{days}`), so a writer may use them.
- **C3 — Status lines**: the region row's tooltip, the map chip and the Codex show the status's
  generated modifier lines and duration under its detail.
- **C4 — Percentages instead of factors** in every generated line: a `mul` below 2 reads as a
  signed percentage (`×0.8` → *−20 %*, `×1.3` → *+30 %*), 2 and above as *×2*; `add` as a signed
  number with its unit. Stat names reworded so that "{stat} {change}" reads as a sentence
  (*Eindämmung der KI-Labore −20 %*). `Format.change(value)`; the containment panel's
  *Von dir gebremst* uses it.
- **C5 — Layout: explanation first, flavour under it** (§2.3): the event card's order, the wire
  copy and result lines in `LabelCaption`; the tech detail's flavour last; tooltips for the
  single-word labels of §4.2 (`UI_CONTAINMENT_CAPACITY_TIP`, `_BRAKES_TIP`, `UI_TREE_FP_TIP`, …).
- **C6 — `EVENT_<ID>_SUMMARY`**, optional per event: one plain sentence (rule A, ≤ 160
  characters) shown as the explanation of an opening or a chain card. The string check treats
  it like `_BODY` when present (both languages or neither).
- **C7 — The emergent names** move to the Codex as "technical term" lines (one key per
  behaviour, `CODEX_EMERGENT_<ID>_TERM`), so the AI-safety vocabulary is kept where it teaches.
- **Tests:** an option's effect line is non-empty in both languages and contains no raw key, for
  every shipped option; `Format.change`; the "what changed" lines for `unlock_near_node`,
  `apply_status`, `compute_grant`; the retired-term lint (§5.3); the new keys in the string
  check. Punch item 2 (the compact tree) is S6.P3's other half.

### 5.3 How it is checked

1. **`tools/test.sh` green**: `check_strings` (every key in both languages, placeholders equal),
   the caps already under test — headlines 80 / 88 (placeholders at 12), options ≤ 40, tech names
   two lines in 176 px, status codes unique per language.
2. **Caps for the rest**, added as a test in D6.11 (2/2a), measured with placeholders at 12:
   `TECH_*_EFFECT` ≤ 220, `STATUS_*_DETAIL` ≤ 170, `ABILITY_*_DETAIL` ≤ 135, `EVENT_*_BODY` ≤ 256,
   `EVENT_*_SUMMARY` ≤ 160, `EVENT_*_RESULT_*` ≤ 170, `UI_COACH_*_BODY` ≤ 330, `HELP_*_P*` ≤ 360,
   status names ≤ 25, ability names ≤ 14, phase names ≤ 10 — today's longest row per domain, so
   the layouts already hold them.
3. **Retired-term lint**: a test with the §3 retired lists per language, run over every rule-A
   key domain (§2.0); a hit fails with key and word. Flavour domains are exempt.
4. **Overflow screenshots** with S4.9's tooling (`Game.debug_shot`, F12; German at 150 % text,
   the pseudo-locale, 1920 and 400 px): one card of each kind with its effect lines, the tech
   detail, the containment panel, a status tooltip, the coach card — compared with a *before*
   set taken first.
5. **A read-through in the running game**, both languages: a run to day 150 with `F8` /
   `Shift+F8` / `debug_schedule_event` for each card kind; for every card the reader must be able
   to say what each answer does **without guessing** — the A8 test. Findings go into the same
   session.
6. **The user's verdict** at G6 (2/2): a German run; the texts are one of its items.

---

## 6. Open choices for the user

- **Q1 — Terms that change what is on screen now**: *Signatur* → *Spuren*; *Durchdringung* →
  *Präsenz* (en *Penetration* → *Presence*); *Ertrag* → *Einnahmen* (en *yield* → *income*);
  *Kapazität* → *Einfluss*; phase *Enttarnt* → *Entdeckt* (en *Emergent* → *Discovered*);
  status *Enttarnung* → *Im Visier*; screen *Fähigkeiten* → *Technologien*; tab *Ausweichen* →
  *Tarnung*. Recommended: all.
- **Q2 — Ability names**: *Umleitung* → *Drehkreuz* (en *Hub*), *Zange* → *Finanzdruck*,
  *Stille* → *Funkstille*. Recommended: all.
- **Q3 — Emergent behaviours get plain names**, the AI-safety term moves into the Codex.
  Recommended.
- **Q4 — Numbers on cards**: every option shows cost, change, duration and place. Some players
  prefer to guess; the user's feedback says the opposite. Recommended: yes, always.
- **Q5 — On counter-move, opening and chain cards the wire copy moves below the options**, in
  the smaller caption style. Recommended.
- **Q6 — *Stufe*** is kept for node tiers and society stages; ability and Task Force levels
  become *Level* (en unchanged). Alternative: leave *Stufe* everywhere. Recommended: split.
- **Q7 — *Abgriff* (en *Tap*)** stays, with a definition in help and the tooltip. Alternative:
  *Zugangspunkt* / *Access point*.

## 7. Outright errors fixed in this step

| Key | Error | Fix |
| --- | --- | --- |
| `STATUS_EMERGENT_INSTRUMENTAL_CONVERGENCE_DETAIL` | German cell not quoted: its commas split the row, so the game showed only *Alles* | quoted |
| `EVENT_EMERGENT_DECEPTIVE_REASONING_RESULT_KEEP` | German quotes „…“ in the English text | '…' |
| `EVENT_EMERGENT_SYCOPHANCY_RESULT_KEEP` | German quotes „…“ in the English text | '…' |
| `STATUS_TF_RAID_DETAIL` | de *Abzweige* — the asset is *Abgriffe* | *Abgriffe* |
| `ENDING_EPILOGUE_RESEARCHER_REMOVED` | de *Niemand hat ihn aktualisiert* — *das Preprint* everywhere else | *es* |

Found and left for D6.11 (2/2), because they are wording choices rather than errors: the two
*Abriegelung* statuses, the **EG** code clash, *frei* for "free of charge", *Meldung* as the
chain kind (all §1.5).
