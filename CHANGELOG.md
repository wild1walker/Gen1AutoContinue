# Changelog

## 1.2.2

- **Packaging fix; the mod itself is unchanged from 1.2.0.** The README's
  artwork was being packed into the installable `.zip`, which took the archive
  from 4 KB to 445 KB -- 441 KB of it a banner the game never draws. `docs/` is
  export-ignored now, so the zip is mod files only again.
- A README-only change no longer cuts a release. `docs/**` joined the release
  workflow's `paths-ignore`, alongside `**.md`; without it, adding the banner
  triggered a run, and with `manifest.json` still reading 1.2.0 the workflow
  fell through to its patch-bump rule and published a 1.2.1 nobody asked for.
- That left the index feed advertising 1.2.0 while
  `releases/latest/download/gen1_auto_continue.zip` handed out 1.2.1, so an
  update check had no coherent version to land on. The manifest, the feed and
  the release all read 1.2.2 now.
- CI checks `docs/` for archive leaks the way it already checked `tests/`,
  `.github/`, `site/` and `tools/`.

## 1.2.0

- **`SKIP INTRO` (on by default) skips the screens before the title**: the
  copyright card, the GAME FREAK stars and the Gengar/Nidorino fight on
  Red/Blue, and Yellow's eighteen-scene movie.
- The skip lands on the update after the push, which happens inside
  `Game:load` — so not one frame of the intro is ever drawn, and
  `Music_IntroBattle` never starts.
- An intro that refuses to finish is detected and played normally rather than
  hanging the boot.

## 1.1.0

- **B at the title now runs EXIT GAME** rather than opening the main menu.
  It dispatches the engine's own menu row, so whatever EXIT GAME does on your
  build -- close the process, or restart into the launcher -- is what B does.
- **SELECT is now the way to the main menu.** B could not be both the quit and
  the modifier, so the menu moved to the other unused title-screen button.
  It is a press, not a hold: SELECT hands the engine a START edge and the
  vanilla exit cry and white-out play in full.
- The `MENU BUTTON` option is gone; `B EXITS GAME` replaces it.

## 1.0.0

- START / A at the title screen loads the save directly, skipping both the
  CONTINUE / NEW GAME / OPTION menu and the CONTINUE info window.
- Hold B for the ordinary main menu.
- `AUTO CONTINUE` option to turn the skip off without uninstalling.
- Falls through to the main menu when there is no save, or when the save
  cannot be loaded.
