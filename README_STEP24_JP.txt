SHATTERED CROWN ECHO STEP24 — Cut-in & Boss Layout Fix

Base: STEP22 complete Godot FIX v3 (Web Solo test project).
This is a full standalone Godot project, not an incremental patch.

Changes:
  - Ordinary player cards: no portrait cut-in; 3-head weapon/skill/guard animation still plays.
  - Finisher role (role == 決着技): retains high-body portrait cut-in.
  - R1-B01 only: model scale 1.12 -> 0.98, base moved from (940,506) to (947,478).
  - R1-B01: redundant floating HP/Intent box hidden; top HUD still displays both.
  - R1-B01: target button enlarged (invisible) to cover face/body/legs.
  - Boss attack cut-in and phase animation: unchanged.
  - BattleController, cards, enemies, campaign, save, EOS/network: unchanged.

Windows Godot:
  1) Extract this ZIP to a *new* folder.
  2) Import project.godot from the extracted shattered_crown_echo_STEP22_COMPLETE folder.
  3) In the FileSystem panel, open res://ui_trial/battle_ui_step21_lab.tscn.
  4) Press F6 for a R1-B01 boss test; no campaign save updates from this lab.
  5) Use C001 etc. Normal cards should NOT show the portrait cut-in.
  6) Check a role=決着技 card (if drawn): portrait cut-in should appear.
  7) Check the boss is fully above the card area and its top HUD Intent remains readable.

Note: The project was validated for ZIP completeness and static source changes.
Godot runtime, scene parsing, portrait timing, and target interaction have NOT
been executed in this environment; confirm these on your computer.

DO NOT replace your production Windows/EOS project with this Web Solo test build.
