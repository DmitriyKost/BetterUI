# Better UI

Lightweight addon that provides small quality-of-life improvements for the default Blizzard UI.

The addon is modular, so individual features can be enabled or disabled from the in-game settings panel.

---

# Features

## Character Window Improvements

* Displays secondary stat ratings alongside percentages in the character panel.
* Displays equipped item levels directly on equipment slots.
* Shows enchant and socket icons, and flags missing enchants and empty sockets in item tooltips.
* Adds the same item level, enchant, and socket overlays when inspecting another player.
* Provides separate settings for each overlay type and for character and inspect frames.

---

## Brewmaster Monk Tools

### Stagger Bar – Uncapped Stagger Value

Blizzard’s default stagger bar caps the displayed stagger amount at 100% of your maximum health, even though the real stagger pool can grow far beyond that.

This addon replaces the default stagger bar text with a custom display that shows the true uncapped stagger value.

---

### Black Ox Statue Removal Button

Creates safe clickable buttons that allow quick Black Ox Statue removal using macros.

```
#showtooltip
/click [mod:alt] BUI_Utils_TotemButton1
/click [mod:alt] BUI_Utils_TotemButton2
/click [mod:alt] BUI_Utils_TotemButton3
/click [mod:alt] BUI_Utils_TotemButton4
/cast [nomod,@cursor] Summon Black Ox Statue
```

---

## Unit Frame Enhancements

### Health Bar Overlays

Adds absorb value to health bars (requires Interface->Display->Status Text to be 'Both'):

* Current HP
* HP percentage
* Absorb values

---

## Performance Monitor

Optional movable on-screen performance text showing:

* FPS
* Home latency
* World latency
* Horizontal or stacked layout
* Class-colored or white text
* Configurable font size and refresh interval
* Position reset from settings

---

## Merchant Assistant

Optional merchant automation that can:

* Sell poor-quality junk and report the gold earned.
* Repair equipment and report the cost.
* Prefer available guild repair funds before using personal money.

All merchant actions are disabled by default.

---

## Tooltip Details

Optional flags add item, spell, NPC, enchant, and gem IDs to Blizzard tooltips. Each detail type can be enabled independently.

---

## Action Bar Tweaks

The Action Bar Control Center provides per-bar checkboxes for Action Bars 1-8. Each bar can be configured independently without entering action bar IDs manually.

### Hide Action Bar Borders

Hide button borders on selected action bars.

---

### Hide Macro Text

Hide macro labels on selected action bars.

### Click-Through Action Bars

Prevent selected action bars from receiving mouse clicks while keeping their keybinds functional.

---

# Installation

1. Download or clone the repository.
2. Extract the folder into:

```
World of Warcraft/_retail_/Interface/AddOns/
```

3. Reload UI:

```
/reload
```

---

# Configuration

Settings are available in:

```
Game Menu → Options → AddOns → BetterUI
```

or via slash command:

```
/bui
```

---

# License
Beer-Ware License.
