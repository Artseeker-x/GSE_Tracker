### Fixed
- Settings GUI lag eliminated — slider +/- buttons and enable/disable toggles now respond instantly
- Added state-signature cache to combat marker and assisted highlight control functions: bails early when enabled/locked/color state is unchanged, eliminating ~60 redundant WoW frame API calls per click
- Added value guard to slider sync: only calls SetValue when the value actually differs, preventing cascade OnValueChanged re-triggers
- RefreshCombatMarkerControls now routes all slider updates through the guarded sync function
