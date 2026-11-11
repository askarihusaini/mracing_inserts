# MRacing MR27 Insert Calculator: Context for Claude

ME450 capstone (University of Michigan, MRacing FSAE). We are sizing potted inserts for a
CFRP / aluminum-honeycomb monocoque. The main file is now `Resin_Puck_Calculator_MR27.m` (root).
Read this whole file before editing the calculator.

## REPO LAYOUT (Nov 2026)
- `Resin_Puck_Calculator_MR27.m`: THE calculator. One standalone script, no helper files. It follows the
  section layout and variable names of `g7_plug_calculator/G7_Insert_Calculator_MR27_20261008.m` (the
  original). Inputs: resin puck material, `puck_bolts`, `puck_shape` ('figure8' or 'stadium'),
  `load_mode` ('bracket' or 'direct'). Outputs: puck radius, failure modes (ECSS, punch-out, spool flange
  + wall, floor) with the governing one, required splice bond, spool neck compression.
- `g7_plug_calculator/`: the original G7 plug calculator (standalone), kept for reference.
- `multi_file_calculators/`: the earlier refactor (worker functions, CSV batch, sensitivities, standard
  sizes). It includes `G7_Insert_Calculator_MR27.m` (multi-file G7/potted version) and
  `MR27_Resin_Puck_Calculator.m` (multi-file resin puck version). They share the helper files in that
  folder, so run them with that folder as the MATLAB current folder. Superseded, not maintained.
- `reference/`: MR25 Chassis Inserts.xlsx, MR27 Suspension Loads Rev15, and the v2 / MR25 .mlx calculators.
Where the notes below say `resin_puck_size.m`, `hardpoints_MR27_resin_puck.csv` etc., they now live in
`multi_file_calculators/`.

## DESIGN CHANGE (Nov 9 2026, user): global 6.1 pcf core, spliced resin puck
The global panel core is now 6.1 pcf (no more 3.1 pcf panels), so a higher-density core puck is NOT
worth splicing. New design: an Al NAS03 spool is cast in a PRO-SET LAM-151-HT resin puck (unfilled,
no glass beads) in a jig and fully cured; the puck is then spliced into the panel core with 3M
AF 3074 core splice film and co-cured at 350 F. New calculator: `MR27_Resin_Puck_Calculator.m` (+
`resin_puck_size.m`, `core_library.m`, `hardpoints_MR27_resin_puck.csv`; on git branch
`resin-puck-calculator`). It outputs the resin puck radius and the REQUIRED splice bond strength; the
puck is sized as one rigid insert of radius R in the 6.1 pcf panel core (ECSS) + punch-out + a
geometric floor. The older two-level / puck-in-3.1-pcf-panel sections below describe the SUPERSEDED
concept and are kept for history. User answers (Nov 2026): two bolts CAN share one puck (default
`puck_layout = 'shared'`, one round puck per bracket); spool flanges are flush with the skins and the
resin is slightly inset to fit under the skins (inset value unknown, parameter `inset_each_face_in`,
placeholder 0); rigid-plug ECSS convention (the resin does not fill the cells); core height c = 1 in
confirmed; layup still a placeholder (user will ask the composites lead).
The user's intended shared puck is TWO OVERLAPPING CIRCLES (`puck_layout = 'overlap'`, default); ECSS
only covers one circular insert, so the union is sized with an equal-PERIMETER equivalent circle
(ours, not ECSS; ignores the two re-entrant cusps). `'shared'` (one big round puck) and `'separate'`
remain selectable.
Results at Rev15 (FLCA fore): puck loads P 3599 lb, M 278 lb-in. Overlap: lobe R 1.75 in std (1.734
needed), outline 5.02 x 3.50 in, ~267 g net per bracket. One big round puck: R 2.25 in, ~286 g.
Separate pucks: R ~1.1 in each, ~151 g, but do NOT fit at a = 1.52 in. Splice shear ~255 psi average,
~272 psi peak with M on the puck wall. 3M AF 3074 FST data (preliminary TDS, June 2025, in
`splice_lookup.m`): cure 250-350 F, expansion ~225% (257 F) / ~125% (320 F), 30/50 mil film
(0.9/1.6 kg/m^2), tube shear on SOLID Al tubes 1883 psi at 73 F (257 F cure only, no 350 F data).
That is NOT a honeycomb allowable: the bracket is foil-edge-only ~68 psi (x solidity 3.6%) to 1883
psi; the splice allowable default is the core plate shear (placeholder). A push-out coupon is needed.

## Concept (as of Nov 2026, SUPERSEDED by the design change above)
- Lead option: an Al spool potted (INF-114 epoxy + glass beads) into a pre-made puck of
  higher-density core (currently 6.1 pcf, to be confirmed). The puck is spliced into the
  surrounding panel core and co-cured at 350 F.
- G7 plug is STILL A LIVE OPTION (depends on material availability). Keep it as a selectable
  insert type alongside the potted spool, and make the puck / two-level sizing work for either
  insert type. Its main drawback: a solid G7 plug weighs about 2.4x a potted insert at the same
  radius (G7 about 1.68 g/cc vs bead-filled potting about 0.68 g/cc). Update Nov 2026: the potting is
  now planned to be UNFILLED Pro-Set LAM-151-HT (1.13 g/cc, no glass beads), co-cured at 350 F with the
  panel. That shrinks the ratio to about 1.5x. The script defaults to this (`potting_material`,
  `bead_factor = 1.0`); INF-114 + beads remains selectable.
- Core density VARIES PANEL TO PANEL: some panels are 3.1 pcf, others differ. Both the panel
  (low-density) core and the puck core must be switchable inputs, chosen per hardpoint, not
  hard-coded. Suggested approach: a small core-property library (designation -> cell size, foil,
  density, tau_W min/typ, G_W) selected by name, with the panel core and puck core set per load
  case / hardpoint. Ask the user which densities each hardpoint's panel uses.

## File lineage (who wrote what)
- `Insert_calculator_2025_v2_1.mlx` (MR25/MR26): ECSS-E-HB-32-22A core-shear method. It read
  P1/P2/Q/M from an xlsx and hard-coded the core and skin properties.
- `Insert_Calculator_MR25.mlx` (v1, Aidan 2023): obsolete. It has known bugs (dummy K_max at a
  1 in radius, an odd bp fit, and an interaction sum set equal to SF). Do not use it.
- Nov 2026 refactor: the math now lives in `size_hardpoint.m`, `ecss_core.m` (the unchanged ECSS
  equations), `hardpoint_loads.m`, `insert_margins.m`, `insert_mass.m`, `core_lookup.m`, plus
  `read_hardpoint_csv.m` and `hardpoints_MR27.csv` (batch), and `potting_lookup.m` (potting compound
  by name: INF-114 baseline, or Pro-Set LAM-151-HT from its Rev 6 / Mar 2025 datasheet: neat 1.13 g/cc,
  neat compression yield ~16.3 ksi, Tg 328-357 F depending on post-cure, no data at a 350 F cure;
  the x0.6 glass-bead factor is assumed for it, not measured). The main script only sets inputs and
  prints. The legacy output reproduces the original numbers exactly (checked at 8150 N).
  Core library, puck/two-level sizing, direct load mode and the load-split switch were added then.
  Tested in MATLAB R2025b only, NOT yet in Octave.
- `G7_Insert_Calculator_MR27.m`: written in an Oct 2026 Claude session from v2, then edited
  by the user. Everything below was added in that session; none of it is in v2:
  - Loads built from link force + bracket FBD (type A and B). This copies the logic in the
    MR26 Chassis Inserts sheet; v2 itself did not do it.
  - Per-material plug properties, face-sheet punch-out, edge distance, washer crush,
    bolt bearing, plug punch-through, and a cure-temperature warning.
  - Plug-to-core bond, REPORTED as a required strength (tau_req = P/(2*pi*b*c)), not used
    for sizing. tau_bond_allow defaults to Twcrit (the user asked for this, to match v2's
    implicit assumption that the core fails before the bond).
  - Exact radius at the MS = 0 crossing (v2 averaged the MS = +/-0.05 band), no rounding
    (b_step = 0).
  - Potted-insert failure-mode breakdown. Skin punch-out is applied to the potted insert too.
    v2 never checked it, and with thin MR27 skins it governs.
  - Mass from NAS03 spool geometry plus potting volume.

## Equations: what is ECSS and what is ours
- ECSS (keep unchanged unless the user approves): beta, alpha, C*, r_tmax curve fit, K_max,
  P_crit [C.2-6 ... C.2-17], Qss = 8 b^2 tau + 2 f b sigma_fy [14.2-1],
  Mss = P_crit*b_i, and the interaction (P/Pss)^2 + (Q/Qss)^2 + (M/Mss)^2 <= 1.
- Pss = 0.89*P_crit (knockdown applied to P only; Mss uses P_crit without it). This is how v2
  does it.
- Potted: bp = bi + 0.35*Sc, and Mss uses bi. Plug: b everywhere.
- Qss validity: v2's comment says the fit is only valid for bp < 0.433 in. Current designs are
  about 0.7-1.0 in, so the Q term is extrapolated.
- Skin vs core share of Qss: they are equal at b = f*sigma_fy/(4*tau_w). That gives about
  0.83 in for 3.1 pcf (90 psi) but only about 0.27 in for 6.1 pcf (272 psi) with the
  3 x 0.18 mm skins. So "skins dominate in-plane" is true in the low-density core but NOT
  inside a 6.1 pcf puck at b ~ 1 in. sigma_fy is the skin interlaminar shear strength
  (14 ksi, a placeholder carried over from v2); a laminate bearing strength would be more
  appropriate.
- The core term uses plate shear strength, not crush strength.

## Load conventions (verify in code)
- Type B: P = SF*F*cos(a)/2 per insert, Q = SF*F*sin(a) - 2*mu*F_pre (WHOLE-bracket shear and
  whole-bracket friction), M = SF*F*sin(a)*y (WHOLE-bracket moment on each insert).
  This is "method 1" in the MR26 sheet: deliberately conservative, but internally
  inconsistent with P. Changing it to a per-insert split changes results, so flag it first.
- Type A: P1,2 = SF*(F*cos(a)/2 +/- F*sin(a)*y/a_bolt), worst bolt used, M = 0.
- Friction default: 2 x 2125.8 lb x 0.2 = 850 lb per bracket. This zeroes Q for every
  control arm at SF 2-2.5. The MR26 sheet's actual torque-spec preloads are much lower
  (87-1516 lb; FLCA fore 1156 lb) and use mu = 0.175.
- Default load case: MR27 Suspension Loads **Rev14**, FLCA fore, Cornering 3 (2.2 g),
  8150 N compression, 10.45 deg from normal, y = 0.4185 in, a = 1.52 in, type B, SF 2
  -> P = 1802 lb, Q = 664 lb before friction (0 after), M = 278 lb-in.
  The slides cite Rev15 (8140 N): flag the mismatch.
- The radius does not depend on load direction: the interaction squares the loads, so size to
  max |F|. Testing is planned in pull-out (tension), which is conservative for that direction.

## Core property conventions
- From Hexcel HexWeb CR-III 5052, W direction (weakest), MINIMUM shear strength (typical in
  brackets), W shear modulus. A starting point for the core library; verify against the
  supplier's datasheet for the core actually bought:
    1/8"  3.1 pcf:  90 (130) psi, G_W 22.0 ksi     3/16" 3.1 pcf:  90 (125) psi, 22.0 ksi
    1/8"  4.5 pcf: 168 (220) psi, G_W 31.0 ksi     3/16" 4.4 pcf: 160 (215) psi, 30.0 ksi
    1/4"  4.3 pcf: 155 (200) psi, G_W 29.8 ksi     5/32" 3.8 pcf: 125 (165) psi, 26.4 ksi
    1/8"  6.1 pcf: 272 (340) psi, G_W 41.0 ksi     3/16" 5.7 pcf: 244 (300) psi, 38.5 ksi
    1/8"  8.1 pcf: 400 (470) psi, G_W 54.0 ksi     3/16" 8.1 pcf: 400 (480) psi, 54.0 ksi
  Hexcel CR-III 5052 has no 4.1 pcf grade; if a panel is "4.1 pcf", confirm the designation.
- DECIDED (Nov 2026, user): Gc = G_W, no /3. v2 and the MR26/MR25 sheets used G_W/3 (v2: Gc = 13667
  = 41000/3 for 6.1 pcf), source unknown (the MR25 "Core Data" sheet links a PC Composites
  datasheet, possibly the origin). The /3 is NOT conservative: a lower Gc gives a smaller radius.
  The script keeps `Gc_scale` only as a sensitivity knob (1/3 shrinks the puck insert ~3%).
- Hexcel shear data is measured at 0.625 in thickness. Thicker core has lower strength
  (Hexcel K-factor), which is not applied yet.

## Results and validation so far
- ECSS core shear vs MR25 Instron tests: at a 0.75 in potting radius, 2 inserts, predicted
  about 18.3 kN (typical strength) vs 15.0-18.5 kN measured; at a 0.5 in radius, predicted
  about 14.3 kN vs 12.5 kN measured. This is the only calibration evidence, and it is for
  axial pull-out only. Nothing in-plane has been calibrated.
  CORRECTION (Nov 2026, from `MR25 Chassis Inserts.xlsx`, sheet "Testing Catalog"): the 18.3 / 14.3 kN
  figures above are NOT in that workbook and could not be reproduced. The sheet's own predictions
  (expected min / avg, 2 inserts, f 0.055 in, c 0.75 in, G_W/3) are 12.6 / 15.7 kN at r = 0.75 in,
  10-11 / 14 kN at 0.5 in and 8.1 / 10.2 kN at 0.25 in. Measured: 14-16.2 kN (0.75 in, 5.7 pcf,
  backing plate), 14-14.2 kN (0.5 in, 6.1 pcf), 12.5 kN (0.25 in). All valid tests beat the expected
  minimum by 10-35%. The 1 in tension test without a backing plate failed by SLIPPING at 5.4 kN vs
  15.4 kN expected. Our ECSS code with G_W/3 reproduces the sheet's minimums to ~1-4% (0.75 and 0.5 in);
  with G_W it predicts 10.8 / 8.0 / 5.1 kN (0.75 / 0.5 / 0.25 in), i.e. much more conservative.
- The 3.4 in radius with 3.1 pcf core is NOT the calculator being too conservative. It
  follows from 90 psi core vs 272 psi in MR25's tests. A puck (dense-core patch) is the fix.
- Puck sizing approach (agreed in Oct): treat the puck as one large rigid insert of radius R
  in the surrounding panel core (re-run the ECSS check with that panel's core properties) plus
  the splice requirement tau = P/(2*pi*R*c). This applies the same way whether the insert
  inside the puck is a potted spool or a G7 plug. With 3.1 pcf, single insert: R ~ 3.39 in. A 2-bolt bracket
  sharing one puck carries 2P across the puck edge, so R ~ 6.8 in.
- With 8.1 pcf puck, c = 1 in, 3 x 0.18 mm skins: potting radius 0.743 in from core shear, but
  skin punch-out governs at 0.963 in (tau_f_punch = 14 ksi PLACEHOLDER). Rerun for 6.1 pcf.
- Spool neck compression (NAS03: neck 0.291 in OD, 0.191 in bore, area 0.0379 in^2):
  preload only gives 56 ksi at v2's 2126 lb (30.5 ksi at the 1156 lb torque spec); with
  +1802 lb push-in, 104 / 78 ksi. 6061-T6 yields at about 35-40 ksi. A neck-only check
  FAILS. The potting shares compression in reality. Flagged in the DR2 slides.

## Known issues in the MR26 Chassis Inserts sheet (if reading it)
- "Al 6061 density (kg/in^3) = 0.098" is actually lb/in^3, so the spool mass is lb, not kg.
- Sheet16's "SF = 2" row matches v2 at SF 2.5. The "SF = 3" row is correct.
- The Control Arms tab "MATLAB CALCULATOR RESULTS" rows used OLD (MR25-era) loads from the
  side table in columns S-Z, not the MR26 loads.

## Placeholders (must stay visibly flagged)
tau_f_punch, sigma_fy, tau_bond_allow (= Twcrit), all G7/G10/G11 properties, the potting
density (0.68 g/cc, the sheet's x0.6 glass-bead assumption), eD_min, bolt preload and mu,
the Gc convention, and the MR27 layup (n_plies, t_ply, Ef).

## Environment notes
- No MATLAB in cloud sessions. Octave installs with `apt-get install -y octave` and runs the
  script (headless; set make_plots = false). `yline` needs MATLAB R2018b+ or a recent Octave.
- Keep the script MATLAB/Octave-compatible: no local functions defined before code in a script
  (put functions in separate .m files or at the end with MATLAB R2016b+), and no Octave-only
  syntax (#, !=, ++).
