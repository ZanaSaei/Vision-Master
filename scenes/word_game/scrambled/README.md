# بازی املا — Scrambled Words

A drag-and-drop spelling game for the Vision-series vocabulary: the letters of
a word are dealt shuffled onto a row of candy tiles and the player drags them
into order. Two ways in: **learning mode** (pick a book and a lesson, free
practice, no score) and a **daily competition** (the same five words for
everybody, one score out of 500 per day).

## Where everything lives

| File | Role |
| --- | --- |
| `scrambled_data.gd` | Loads `res://data/scrambled_words.json` (guarded; an unreadable bank is an empty bank, never a crash). |
| `word_controller.gd` | One word: the answer, the seeded scramble, the solved/near-miss checks. |
| `daily_word_picker.gd` | Today's five words. Date-seeded and frozen, like کلمه روز. |
| `score_manager.gd` | The score table, the daily record and the practice record (`user://scrambled_words.json`). |
| `game_manager.gd` | The session state machine both screens drive. |
| `scrambled_theme.gd` | The game's palette and styles. |
| `tile.gd` / `Tile.tscn` | One letter tile — draws itself (see below). |
| `tile_board.gd` / `TileBoard.tscn` | The row, the drag-and-drop, the drop-slot outline. |
| `scrambled_words.gd` + `ScrambledWords.tscn` | The entry point: header bar + screen host. |
| `mode_select` / `lesson_select` / `gameplay` / `results` | The four screens, each instanced inside the host. |
| `test_scrambled_words.gd` + `TestScrambledWords.tscn` | Tests — run with `run_scene`. |

`SpellingGame.tscn` (the hub's «بازی املا» button) is now a thin host that
shows `ScrambledWords.tscn`, so every existing link keeps working.

## Adding books, lessons and words

Edit **`res://data/scrambled_words.json`**. Nothing else needs to change —
the lesson screen, the word counts and the daily bank all rebuild from it.

```json
{
  "schema": 1,
  "books": [
    {
      "book": 1,
      "title": "Vision 1",
      "grade_fa": "پایه دهم",
      "lessons": [
        {
          "lesson": 2,
          "title": "Lesson 2",
          "title_fa": "شگفتی‌های آفرینش",
          "words": [
            {
              "word": "planet",
              "meaning": "A large round object in space.",
              "meaning_fa": "سیاره"
            }
          ]
        }
      ]
    }
  ]
}
```

Rules the game relies on:

* `word` — **Latin letters only, 3–12 characters**, unique inside its lesson
  (longer words just shrink the tiles; a 12-letter word still fits one row).
* `meaning` — the English meaning shown when the hint is revealed. Keep it
  short; it is one line on the hint card.
* `meaning_fa` — optional Persian meaning shown under the English one.
* Lessons without a `title_fa` are shown as «درس N».
* Books/lessons/words are used **in file order**; `all_words()` flattens that
  order and the daily picker slices it, so re-sorting the file shifts which
  words each day gets (it never breaks anything).

## How the daily challenge works

* `now_utc_unix()` is the single clock hook (swap in a server time later
  without touching anything else). The UTC day index selects the day.
* The whole bank is shuffled **once with a fixed seed**, then each day claims
  the next window of 5 entries — consecutive days never share a word until
  the bank has been walked through.
* The scramble seed comes from the day + word position, so every player gets
  the same five boards on the same day.

## Scoring

Per word (competition only), by the time taken to solve it:

| solved within | points |
| --- | --- |
| 10 s | 100 |
| 30 s | 60 |
| 50 s | 40 |
| 60 s | 30 |
| slower | 20 |

A word solved after the meaning was revealed loses **10 points** (never below
10), which keeps a daily run between **50** and **500**. The day keeps its
**best** attempt; replays count as attempts but never lower a record. Learning
mode records practice per lesson (words spelled, sessions, hints) word by word,
so leaving a long lesson halfway keeps what was already done.

## Design decisions worth knowing

* **Why the tiles draw themselves** (`tile.gd`, like `WordleTile`): the
  app-wide theme walk (`ThemeService`) restyles every Panel/PanelContainer/
  Label it finds and would erase the candy colours mid-puzzle. A self-drawing
  Control is invisible to that walk. The screens are also listed in
  `ThemeService.SELF_THEMED_SCRIPTS` so the walk skips the whole subtree; the
  header is themed explicitly via `Global.style_header()` and the rest reads
  the palette through `ScrambledTheme` — on a live theme toggle included.
* **The drag feel**: the carried tile is scaled up (1.15), lifted above the
  finger with a deepening shadow, and the neighbours slide aside with
  `TRANS_BACK` easing; a pulsing outline shows the slot it would drop into.
* **Never punished, never given away**: a wrong arrangement is simply placed.
  Only when the word is one or two letters away do the misplaced tiles pulse
  amber ("nearly there") — the answer itself is never shown, and the hint only
  ever gives the *meaning*.
* The board's children are **only tiles** (`_finish_settle` re-syncs the child
  order after each move), so don't add other nodes under `TileBoard`.

## Testing

Run the test scene (`run_scene` on `TestScrambledWords.tscn`): it parks the
real `user://scrambled_words.json`, exercises the bank, the daily picker, the
scramble rules, the score table, both records, both session flows and the
drag-and-drop board, then puts the save back. Running the game itself
(`ScrambledWords.tscn`) exercises the screens, which need the real autoloads.
