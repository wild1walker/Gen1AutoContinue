-- Standalone: lua5.1 mods/gen1_auto_continue/tests/gen1_auto_continue_test.lua
--
-- The mod attaches to whatever screen.pushed hands it, so the suite hands it a
-- stand-in TitleState with the same shape and the same call order as
-- src/ui/TitleState.lua: update() leaves the attract loop on a press, the cry
-- resolves into toMenu(), toMenu() sets menuOpen and calls openMenu().  A
-- successful onContinue mirrors Game:restoreSave by emptying the stack and
-- pushing the overworld, which is the signal the mod reads.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")

local MOD = "mods/gen1_auto_continue"
local ID = "gen1_auto_continue"

-- ------- the stand-in

local Title = {}
Title.__index = Title

-- One frame of Input:step: a queued edge (mod.input:tap) becomes wasPressed on
-- the *next* step, which is the timing the SELECT path depends on.
local function newInput()
  local queue, pressed, held = {}, {}, {}
  return {
    isDown = function(_, btn) return held[btn] or false end,
    wasPressed = function(_, btn) return pressed[btn] or false end,
    sourcePress = function(_, btn) queue[#queue + 1] = btn end,
    sourceRelease = function() end,
    _step = function()
      pressed = {}
      for _, btn in ipairs(queue) do pressed[btn] = true end
      queue = {}
    end,
    _press = function(btn) pressed[btn] = true end,
    _hold = function(btn) held[btn] = true end,
  }
end

local function newGame()
  local states = {}
  return {
    input = newInput(),
    stack = {
      states = states,
      top = function(self) return self.states[#self.states] end,
      push = function(self, s) self.states[#self.states + 1] = s end,
      pop = function(self)
        local s = self.states[#self.states]
        self.states[#self.states] = nil
        return s
      end,
      clear = function(self)
        for i = #self.states, 1, -1 do self.states[i] = nil end
      end,
    },
  }
end

-- opts.save: "ok" loads, "none" leaves the stack alone, "throw" errors
local function newTitle(opts)
  opts = opts or {}
  local game = newGame()
  local self = setmetatable({
    game = game, phase = "loop", menuOpen = false,
    menuOpened = 0, continued = 0, exited = 0,
  }, Title)
  self.onContinue = function()
    self.continued = self.continued + 1
    if opts.save == "throw" then error("save is corrupt", 0) end
    if opts.save == "none" then return end
    game.stack:clear()
    game.stack:push("OverworldController")
  end
  -- what openMenu will build; EXIT GAME is vanilla's last row
  self.rows = {
    { label = "CONTINUE" }, { label = "NEW GAME" }, { label = "OPTION" },
    { label = "EXIT GAME", onSelect = function() self.exited = self.exited + 1 end },
  }
  game.stack:push(self)
  return self
end

function Title:openMenu()
  self.menuOpened = self.menuOpened + 1
  local out = Runtime.call("ui.title_menu.items",
    function(_, items) return items end, self.game, self.rows)
  self.game.stack:push({ menu = true, items = out })
end

function Title:toMenu()
  -- the whiteFlash frames are not modelled; what matters is that toMenu is
  -- the only caller of openMenu and that menuOpen is set first
  self.menuOpen = true
  self:openMenu()
end

function Title:update()
  if self.phase == "loop" then
    local input = self.game.input
    if input:wasPressed("start") or input:wasPressed("a") then
      self.phase = "exitCry"
    end
  elseif self.phase == "exitCry" then
    self.phase = "loop"
    self:toMenu()
  end
end

-- run n frames, stepping the input edge each time
local function frames(title, n)
  for _ = 1, n do
    title.game.input._step()
    title:update()
  end
end

local function attach(title)
  Runtime.emit("screen.pushed", { state = title })
  return title
end

-- press a button, then run enough frames to reach openMenu
local function boot(title, btn)
  attach(title)
  title.game.input.sourcePress(nil, btn or "start")
  frames(title, 4)
  return title
end

-- ------- the stand-in intro
--
-- Both IntroMovie and YellowIntro are "a screen with finish(), pushed with the
-- title as its onDone".  Screens.build stamps screenId, which is how the mod
-- tells an intro from any other screen that happens to have a finish().

local function newIntro(id, opts)
  opts = opts or {}
  local game = newGame()
  local self = {
    game = game, screenId = id, finished = false,
    frames = 0, done = 0, onDone = function() end,
  }
  self.finish = function(s)
    if opts.stuck then return end -- a finish() that will not take
    if s.finished then return end
    s.finished = true
    game.stack:pop()
    s.done = s.done + 1
  end
  function self:update() self.frames = self.frames + 1 end
  game.stack:push(self)
  return self
end

local function runIntro(intro, n)
  Runtime.emit("screen.pushed", { state = intro })
  for _ = 1, (n or 1) do intro:update(0) end
  return intro
end

-- ------- the runs

local run = T.sdk.loadMod(MOD, { data = { pokemon = {}, moves = {} } })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- 1. the whole point
local t = boot(newTitle({ save = "ok" }))
T.eq(t.continued, 1, "START at the title loads the save")
T.eq(t.menuOpened, 0, "the CONTINUE / NEW GAME menu is never built")

t = boot(newTitle({ save = "ok" }), "a")
T.eq(t.continued, 1, "A works the same as START")

-- 2. SELECT is the way back to the full menu
t = boot(newTitle({ save = "ok" }), "select")
T.eq(t.continued, 0, "SELECT does not load")
T.eq(t.menuOpened, 1, "SELECT opens the ordinary main menu")
T.check(t.menuOpen, "and it opens it the vanilla way, through toMenu")

-- the next press after a SELECT must go back to loading
t = attach(newTitle({ save = "ok" }))
t.game.input.sourcePress(nil, "select")
frames(t, 4)
T.eq(t.menuOpened, 1, "SELECT opened the menu")
t.phase = "loop" -- the player backed out; vanilla replays the title
t.menuOpen = false
t.game.input.sourcePress(nil, "start")
frames(t, 4)
T.eq(t.continued, 1, "the SELECT request does not stick to the next press")

-- 3. B exits
t = boot(newTitle({ save = "ok" }), "b")
T.eq(t.exited, 1, "B runs the engine's EXIT GAME row")
T.eq(t.continued, 0, "B does not load the save")
T.check(not t.menuOpen, "the title art is still up when the quit dispatches")
T.eq(#t.game.stack.states, 1, "the menu built to reach the row is taken back down")

run.loader.modOptions[ID] = { exit_on_b = false }
t = boot(newTitle({ save = "ok" }), "b")
T.eq(t.exited, 0, "B EXITS GAME off leaves B dead, as in vanilla")
T.eq(t.menuOpened, 0, "and does not open anything either")
run.loader.modOptions[ID] = nil

-- 4. the toggle
run.loader.modOptions[ID] = { enabled = false }
t = boot(newTitle({ save = "ok" }))
T.eq(t.continued, 0, "AUTO CONTINUE off restores vanilla boot")
T.eq(t.menuOpened, 1, "AUTO CONTINUE off shows the menu")
t = boot(newTitle({ save = "ok" }), "b")
T.eq(t.exited, 1, "B still exits with AUTO CONTINUE off")
run.loader.modOptions[ID] = nil

-- 5. first boot: nothing to continue, so the menu has to appear
t = boot(newTitle({ save = "none" }))
T.eq(t.continued, 1, "a load is attempted")
T.eq(t.menuOpened, 1, "no save falls through to NEW GAME / OPTION")

-- 6. a load that throws must not strand the player on a dead title
t = boot(newTitle({ save = "throw" }))
T.eq(t.menuOpened, 1, "a failed load falls through to the menu")

-- 7. QUIT from the START menu builds a second title; it gets its own arming
local first = boot(newTitle({ save = "ok" }))
local second = boot(newTitle({ save = "ok" }))
T.eq(first.continued, 1, "the first title is unaffected by the second")
T.eq(second.continued, 1, "a freshly pushed title is patched too")

-- re-emitting screen.pushed for the same instance must not double-wrap
local again = newTitle({ save = "ok" })
attach(again); attach(again)
again.game.input.sourcePress(nil, "start")
frames(again, 4)
T.eq(again.continued, 1, "re-attaching is idempotent")

-- 8. anything that is not a Gen 1 title is left alone
local gen2 = { onContinue = function() end }
Runtime.emit("screen.pushed", { state = gen2 })
T.eq(gen2.update, nil, "a Gen 2 title is not patched")
Runtime.emit("screen.pushed", { state = "OverworldController" })
Runtime.emit("screen.pushed", {})
T.check(true, "non-table and empty payloads do not throw")

-- 9. the screens before the title
local intro = runIntro(newIntro("IntroMovie"))
T.eq(intro.done, 1, "the Red/Blue intro is finished on its first update")
T.eq(intro.frames, 0, "and not one frame of it runs")
T.eq(#intro.game.stack.states, 0, "the intro pops, handing off to the title")

intro = runIntro(newIntro("YellowIntro"))
T.eq(intro.done, 1, "Yellow's eighteen-scene movie is skipped the same way")

run.loader.modOptions[ID] = { skip_intro = false }
intro = runIntro(newIntro("IntroMovie"), 3)
T.eq(intro.done, 0, "SKIP INTRO off leaves the intro alone")
T.eq(intro.frames, 3, "and its own update keeps running")
run.loader.modOptions[ID] = nil

-- an id the mod does not recognise, and which field.boot.screens does not
-- claim either, is none of its business
intro = runIntro(newIntro("SomeOtherScreen"))
T.eq(intro.done, 0, "an unrecognised screen id is not touched")
T.eq(intro.frames, 1, "and runs normally")

-- an intro whose finish() will not take must not strand the boot
intro = runIntro(newIntro("IntroMovie", { stuck = true }), 3)
T.eq(intro.done, 0, "a finish() that does nothing is detected")
T.eq(intro.frames, 3, "and the vanilla intro plays instead of hanging")

-- a screen with no finish() is not an intro, whatever its id
local plain = { screenId = "IntroMovie" }
Runtime.emit("screen.pushed", { state = plain })
T.eq(plain.update, nil, "a screen without finish() is left alone")

run.release()
T.finish("gen1_auto_continue")
