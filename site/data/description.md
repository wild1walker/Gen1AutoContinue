# Gen1AutoContinue

Press START or A at the title screen and your save loads. No CONTINUE / NEW
GAME / OPTION menu, no PLAYER / BADGES / POKéDEX / TIME window — one press
instead of four.

Boot lands on the title, too: the copyright card and the attract movie are
skipped, so the whole launch is title, one press, playing.

The title itself keeps its logo drop, its cycling title mon, its exit cry and
its white-out. That part is the game announcing itself and it costs nothing —
the menu you answer the same way every time is what goes.

## The buttons

| Press | What happens |
| --- | --- |
| START / A | Loads your save |
| B | EXIT GAME |
| SELECT | The ordinary CONTINUE / NEW GAME / OPTION / EXIT menu |

Three buttons, no holds. B and SELECT are both dead inputs on the vanilla
title, so neither takes anything away.

B dispatches the engine's own EXIT GAME row rather than an imitation of it, so
whatever that row does on your build is what B does — on desktop it usually
restarts into the launcher rather than closing the process. There is no
confirmation, which is safe here for one reason: at the title no save is
loaded, so there is nothing to lose.

## Options

| Option | Default | Notes |
| --- | --- | --- |
| `AUTO CONTINUE` | on | Turn the skip off without uninstalling. |
| `B EXITS GAME` | on | Off leaves B dead, as in vanilla. |
| `SKIP INTRO` | on | Off plays the copyright card and attract movie in full. |

## When there is nothing to continue

The main menu appears, as it should. The mod does not probe for a save file —
it asks `onContinue` and reads the answer off the state stack. First boot, a
deleted save and a save too damaged to recover all take that same path.

## Compatibility

- **Link play** — `affects_link: false`. This only moves a menu.
- **Other title-menu mods** — anything wrapping `ui.title_menu.items` still
  works, and SELECT gives you the fully modded menu. This mod wraps that hook
  at the front of the chain but only reads the list; it never alters it.
- **Gen 2** — inert. Gold's title has no main menu to skip, so the mod fails
  its own shape check there and is left out rather than erroring.
- **Autosave mods** — no interaction. This mod reads the save path, never
  writes it.

Requests **no permissions**, and contains no ROM-derived content.
