# Changelog

All notable changes to GSE: Tracker will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.1.4] - 2026-04-08

### Fixed
- Settings GUI lag eliminated — slider +/- buttons and enable/disable toggles now respond instantly
  - Added state-signature cache to `SetCombatMarkerControlsEnabled` and `SetAssistedHighlightControlsEnabled`: bails early when the enabled/locked/color-enabled state hasn't changed, eliminating ~60 redundant WoW frame API calls per click during normal slider adjustments
  - Added value guard to `syncSliderControl`: only calls `SetValue` when the value actually differs, preventing cascade `OnValueChanged` re-triggers for unchanged values
  - `RefreshCombatMarkerControls` now routes all slider updates through `syncSliderControl` for consistent guarding

## [1.1.3] - 2026-04-05
- Initial public GitHub release
