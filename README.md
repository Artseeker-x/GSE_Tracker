# GSE: Tracker

A World of Warcraft addon that provides a compact, configurable action tracker
overlay for monitoring GSE (GnomeSequencer Enhanced) macro sequence execution.

## What It Does

GSE: Tracker displays a real-time overlay showing which actions and abilities
are being used by your GSE sequences as they fire. Designed for players who
use GSE macros and want visual feedback on sequence execution without
cluttering their main UI.

## Key Features

- Compact, movable overlay frame — drag it anywhere on screen
- Tracks active GSE sequence execution in real time
- Minimap button for quick access
- Configurable display modes
- Player tracking indicators
- Assisted highlight for active abilities
- Full options panel via the Blizzard Settings menu
- Supports LibSharedMedia fonts
- Persistent position and settings via SavedVariables

## Compatibility

- **WoW version:** Midnight (retail)
- **Interface:** 120001
- **Required dependency:** GSE (GnomeSequencer Enhanced)
- **Optional dependency:** LibSharedMedia-3.0

## Installation

### Manual

1. Download the latest release zip from the [Releases](../../releases) page
2. Extract the `GSE_Tracker` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. Launch WoW or type `/reload` in-game

### CurseForge / Wago

Install via your preferred addon manager.

## Usage

The tracker frame appears automatically when GSE sequences are active.
Use the minimap button to toggle visibility or open the options panel.

## Options

Open **Settings → AddOns → GSE: Tracker** to configure:

- Display mode
- Font and font size (via LibSharedMedia)
- Frame scale and opacity
- Indicator style
- Player tracking options

## Known Limitations

- Requires GSE to be installed and loaded — the tracker has no function
  without active GSE sequences
- Sequence detection depends on GSE's internal API; major GSE updates
  may require compatibility updates

## Bug Reports

Please open an issue on GitHub with:

- A description of what happened vs. what you expected
- Your WoW patch version
- Your GSE version
- Any error text from the WoW error frame or BugSack

## License

[MIT](LICENSE)
