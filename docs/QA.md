# Soccerpoly · Quality Assurance & Mobile Viewport Verification

<p align="center">
  <a href="QA.md"><b>English</b></a> •
  <a href="QA.ru.md"><b>Русский</b></a>
</p>

This document details the multi-device regression test suites, responsive typography measurements, pawn kinematics validations, and automated gameplay runs across Roblox Studio Device Emulators.

---

## 📱 v0.24.2 — Board Field Typography & Mobile Readability

In the iPhone 7 device emulator, the automated suite audits every purchasable property tile in top-down view:
* **Text Bounds:** Property club names and prices are bounded by dedicated horizontal ribbons. Panoramic artwork occupies at least 10% of card height.
* **Minimum Font Rendering:** On a portrait 374 × 666 viewport across both English and Russian localizations, minimum text height measured via `Roblox TextBounds` reaches **8 logical pixels** for club names and **12 logical pixels** for prices. [Board Overview](../art/studio-overview-ru-v0242.png) · [Club Dossier](../art/studio-dossier-ru-v0242.png)

---

## 🏃 v0.24.1 — Tile Movement & Trajectory Kinematics

In Roblox Studio, 4 pawn pieces start on the `GO` kickoff tile. During dice rolls, the test tracker cross-references moving pawn coordinates with perimeter tile surfaces on every frame:
* **Perimeter Tracking:** Tested across 881 motion frames on iPhone 7 portrait (374 × 666) and 1,008 motion frames on landscape (666 × 374). All coordinates strictly remained on the valid tile path.
* **Purchase Transitions:** Validated camera transitions to the club stadium view, purchase execution, and seamless return to the main board. [Overview](../art/studio-overview-ru-v0241.png) · [Perimeter Motion](../art/studio-perimeter-v0241.png)

---

## 📐 v0.24.0 — Typography Across Diverse Device Profiles

| Device Emulator | Localization | Min Club Name Height | Min Price Tag Height | Status |
| :--- | :---: | :---: | :---: | :---: |
| **iPhone 7 (374 × 666)** | Russian | 16 px | 17 px | PASSED |
| **iPhone XR (413 × 814)** | English | 19 px | 19 px | PASSED |
| **iPhone 7 (666 × 374)** | English (Landscape) | 17 px | 17 px | PASSED |

Automated runs track pawn idle animations, knee bending kinematics during running, and head/foot visibility. Each shot outcome (Goal, Save, Offside) verifies sound effects, credit transfers, and board state restoration. [Landscape View](../art/studio-landscape-v0240.png) · [Goal Animation](../art/studio-goal-v0240.png) · [Goalkeeper Save](../art/studio-save-ru-v0240.png)

To repeat the portrait QA scenario locally, run:
```bash
python3 scripts/studio-qa.py --art --device portrait-small --edition en --shot goal
```

---

## 🌐 v0.22.0 — First-Launch Localization & Environment Baking

* **Default Language:** New sessions open in English by default, while supporting dynamic live switching between Russian and English without resetting match progress.
* **Bsl Texture Baking:** 32 physical club textures, stadium tier models, and 1024 × 1024 skybox environments load seamlessly without missing assets. [High-Res Board 1278 × 718](../art/studio-table-v0220.png) · [Club Purchase](../art/studio-property-v0220.png) · [Portrait View](../art/studio-overview-v0220.png)
