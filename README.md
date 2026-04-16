# Better UI

Lightweight addon that provides small quality-of-life improvements for the default Blizzard UI.

The addon is modular, so individual features can be enabled or disabled from the in-game settings panel.

---

# Features

## Character Window Improvements

* Displays secondary stat ratings alongside percentages in the character panel.

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

---

## Action Bar Tweaks

### Hide Action Bar Borders

Hide button borders on specific action bars.

Example configuration:

```
1,7,8
```

---

### Hide Macro Text

Hide macro labels on specific action bars.

Example configuration:

```
1,7,8
```

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
