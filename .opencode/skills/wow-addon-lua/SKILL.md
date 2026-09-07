---
name: wow-addon-lua
description: World of Warcraft Retail addon Lua development and debugging. Use when editing .toc or .lua addon files, Blizzard UI frames, events, SavedVariables, secure action buttons, combat lockdown, taint, secret values, settings panels, or WoW addon releases.
---

# WoW Addon Lua

Develop and review World of Warcraft Retail addons conservatively. Blizzard UI APIs are stateful, event-driven, and partially protected; code that parses successfully can still taint protected execution or fail only during combat.

## Start With The Addon

Before changing code:

1. Read the `.toc` manifest to determine interface version, load order, SavedVariables, and module boundaries.
2. Read the core initialization and settings code before assuming how features are enabled.
3. Search for related events, hooks, frame mutations, secure templates, and saved keys across the addon.
4. Inspect the current git status and preserve unrelated user changes.
5. Prefer the smallest change consistent with the addon's existing architecture.

Do not assume API signatures from an older expansion. Validate questionable APIs against the target Retail client, current Blizzard FrameXML, or current API documentation.

## Lua And WoW Constraints

- Target WoW's embedded Lua environment, not standalone Lua libraries.
- Do not introduce external dependencies unless the addon already uses them.
- Avoid globals. Use the addon's namespace passed through `...` where available.
- Treat optional Blizzard globals and load-on-demand UI modules as potentially unavailable.
- Guard optional APIs with type or existence checks.
- Use events or focused hooks instead of broad `OnUpdate` polling when safe.
- When polling is necessary, throttle it and avoid allocating tables every tick.
- Remember that `/reload` recreates Lua state but SavedVariables persist.

Run `luac -p *.lua` as a syntax check when `luac` is installed. This does not validate WoW API behavior.

## Feature Lifecycle

For addons using feature modules, follow the repository's established lifecycle, commonly:

```lua
NS.Features = NS.Features or {}

local Feature = {}
NS.Features.Example = Feature

function Feature:Enable()
	if self._enabled then
		return
	end
	self._enabled = true
end

function Feature:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false
end
```

Important lifecycle rules:

- `Enable()` and `Disable()` should be idempotent.
- An already-disabled feature should be a true no-op. Do not traverse or mutate Blizzard frames during startup cleanup when nothing was enabled.
- Hooks installed with `hooksecurefunc`, `HookScript`, or callback registration generally cannot be removed. Gate their callbacks on `self._enabled`.
- Cancel tickers and timers owned by the feature when disabling.
- A delayed callback must re-check feature state and combat state when it runs.
- Do not create recurring work for classes or specs where the feature cannot apply.
- Keep visual restoration limited to state the addon actually changed and recorded.

## Combat Lockdown

Assume Blizzard action buttons, unit buttons, UIPanels, and their secure descendants may be protected.

Before any protected mutation, check:

```lua
if InCombatLockdown() then
	self._pendingUpdate = true
	return
end
```

Resume deferred work from `PLAYER_REGEN_ENABLED`:

```lua
if event == "PLAYER_REGEN_ENABLED" and Feature._pendingUpdate then
	Feature:Refresh()
end
```

Re-check `InCombatLockdown()` inside timer callbacks. A timer scheduled out of combat may execute after combat starts.

Potentially dangerous operations include:

- `SetAttribute` on secure frames
- `Show`, `Hide`, `SetShown`, `SetPoint`, `ClearAllPoints`, or `SetParent` on protected frames
- `EnableMouse` on Blizzard action buttons
- changing protected frame scripts or state drivers
- creating or reconfiguring secure buttons after combat begins
- mutating regions owned by protected buttons from combat-capable events

Cosmetic region changes can still contaminate protected frame hierarchies. Defer them when there is any doubt.

## Secure Action Buttons

Use secure buttons only when a hardware click must invoke a protected action such as casting a spell:

```lua
local button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type1", "spell")
button:SetAttribute("spell1", spellID)
```

Rules:

- Create the button and set protected attributes out of combat.
- Never automate the click; protected actions require a real hardware event.
- Test with the client's action-button-on-key-down preference. Click-phase registration can affect whether an action fires.
- Do not parent or anchor secure buttons into Blizzard UIPanel hierarchies unless necessary. Prefer an addon-owned frame under `UIParent`.
- Do not hide, move, resize, or change attributes on secure buttons during combat.
- If state changes during combat, mark it pending and apply after `PLAYER_REGEN_ENABLED`.

## Hooks And Blizzard Frames

Prefer `hooksecurefunc` when observing a Blizzard function without replacing it.

Avoid direct `HookScript` calls on protected Blizzard UIPanels such as character, inspect, map, or container frames. A script hook can taint shared UIPanel or Escape handling even when the callback seems cosmetic.

Safer alternatives include:

- documented events
- `hooksecurefunc` on a stable Blizzard function or method
- addon-owned throttled visibility detection

Never replace Blizzard global functions or frame methods unless the project explicitly requires it and the taint implications are understood.

When decorating pooled Blizzard buttons:

- Track every button the addon decorates, preferably in a weak-key table.
- Hide addon-owned regions on all tracked buttons when disabling.
- Do not rely only on currently visible or active pool entries; released buttons can be reused later with stale child regions.

## Secret Values

Current Retail clients can return secret values, especially during combat or from restricted aura data.

- Do not compare, concatenate, format, index with, or perform arithmetic on a value that may be secret.
- Use `issecretvalue` when an API result may be restricted.
- If one required value is secret, stop that refresh and hide or preserve the last safe display.
- Do not use `pcall` as a substitute for secret-value handling.
- Treat event payloads as potentially restricted until their signature is confirmed.

Example:

```lua
local value = SomeRestrictedAPI()
if issecretvalue and issecretvalue(value) then
	return nil
end
```

## Events, Timers, And Item Data

- Register the narrowest event available, including `RegisterUnitEvent` for unit-specific events.
- Filter event arguments before scheduling work.
- Coalesce repeated events with one scheduled refresh flag.
- Use `BAG_UPDATE_DELAYED` rather than refreshing for every individual bag slot change when possible.
- Item data can be uncached. Handle `nil` results and refresh after `ITEM_DATA_LOAD_RESULT` when applicable.
- Opening a frame does not always produce a useful data event; use a safe show hook or throttled visibility transition only if needed.
- Avoid permanent high-frequency tickers for information that changes only on events.

## SavedVariables And Settings

- Define defaults in one place and only fill keys whose values are `nil`.
- Preserve explicit `false` values.
- Keep setting names consistent across defaults, UI controls, feature code, and documentation.
- When removing a shipped feature, remove its source file, TOC entry, defaults, application wiring, settings controls, and documentation.
- Obsolete keys already stored in SavedVariables require a deliberate one-time cleanup or migration.
- After confirming a one-time cleanup ran for the intended installation, remove temporary migration code if the project does not retain migrations.
- Do not add compatibility aliases for unshipped or purely local state.

Settings callbacks can run during combat. Each feature must enforce its own combat safety rather than assuming settings are changed out of combat.

## Taint Debugging

For behavior that fails only in combat, treat taint as the primary hypothesis.

1. Reproduce with BetterUI enabled and disabled to establish ownership.
2. Test after `/reload`; taint and permanent hooks can survive a feature toggle for the current UI session.
3. Enable logging with `/console taintLog 2`, reload, reproduce, and inspect `_retail_/Logs/taint.log`.
4. If the log is empty, isolate at module load level by temporarily removing TOC entries in halves.
5. Once a module is identified, separate enable-time behavior from unconditional load-time hooks and disabled cleanup.
6. Remove every temporary TOC edit and diagnostic before committing.

Do not stack speculative fixes. Change one credible taint path, reload, and retest both enabled and disabled states.

Useful combat regression checks include:

- open and close the World Map with Escape during combat
- use action buttons and keybinds during combat
- open or close bags and UIPanels before and after combat
- enable and disable the feature both in and out of combat
- reload with the feature enabled, then reload with it disabled

## Validation Matrix

Static checks:

```text
luac -p *.lua
git diff --check
```

In-game checks should cover:

- `/reload` with no Lua errors
- every supported class/spec and at least one unsupported class
- feature enabled and disabled
- entering and leaving combat
- UI scale and screen-edge positioning for movable frames
- opening, closing, docking, or pooling of any Blizzard frames touched
- cached and uncached item data where relevant
- settings persistence across `/reload`
- secure buttons both in and out of combat

When the game cannot be automated, state exactly which checks require user validation. Never claim `luac` proves in-game correctness.

## Release Review

Before commit, push, or tag:

1. Inspect `git status`, the complete effective diff, and recent commits.
2. Review all commits ahead of the remote base, not only the latest commit.
3. Confirm every `.lua` entry in the TOC exists and load order is correct.
4. Confirm removed features have no source, TOC, settings, defaults, documentation, or SavedVariables references.
5. Run syntax and whitespace checks.
6. Confirm the TOC version matches the intended new tag and that the tag does not already exist.
7. Fetch remote refs/tags and ensure the branch has not diverged.
8. Keep generated or unrelated files out of the commit.
9. Report residual in-game test gaps before publishing.

Do not commit, push, or tag unless the user explicitly requests that operation.
