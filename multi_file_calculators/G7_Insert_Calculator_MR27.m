%% MR27 INSERT CALCULATOR (potted spool and machined G7 plug, optional puck)
% Sizes a machined laminate plug co-cured into the honeycomb as well as a
% potted spool potting radius for comparison, with an optional two-level
% design: insert sized in a higher-density PUCK core, puck sized in the PANEL core.
%
% Equations based on Insert_calculator_2025_v2_1.mlx.
% ECSS-E-HB-32-22A core-shear equations are unedited (see ecss_core.m).
%
% Files: core_lookup.m, ecss_core.m, hardpoint_loads.m, insert_margins.m,
%        insert_mass.m, size_hardpoint.m, read_hardpoint_csv.m, hardpoints_MR27.csv
%
% VALIDATION STATUS: only axial pull-out has any test calibration (MR25 Instron
% tests, "Testing Catalog" sheet of MR25 Chassis Inserts.xlsx). Nothing in-plane
% (Q, M) is calibrated, and every number flagged PLACEHOLDER is unverified.

clear; close all; clc;

%% 0. RUN OPTIONS
make_plots            = true;    % set false for headless runs
run_friction_table    = true;    % section 11: results with / without friction credit
run_convention_table  = true;    % section 12: whole-bracket vs per-insert load split
run_sensitivity       = true;    % section 16: sweeps on the unmeasured inputs
run_batch             = true;    % section 17: all hardpoints in hardpoints_MR27.csv
hardpoint_csv         = 'hardpoints_MR27.csv';

%% 1. LOADS
% load_mode:
%   'bracket' = link force + bracket FBD (suspension control arms), as below
%   'direct'  = enter P, Q, M per insert yourself (aero, non-suspension brackets)
load_mode = 'bracket';
% Direct-mode inputs (applied/unfactored loads PER INSERT; SF is applied below).
% P = out-of-plane (axial) load, Q = in-plane shear, M = moment. Q is used as
% entered: no friction credit in direct mode (shear-dominated hardpoints).
direct_P = 0;                    % lb
direct_Q = 0;                    % lb
direct_M = 0;                    % lb-in

% Default is worst load case (FLCA fore, Cornering 3) from MR27 Suspension Loads Rev15
% (was Rev14 = 8150 N; switched to Rev15 per user). Rev15 contains forces only, so the
% angle, a and y below were NOT re-checked against Rev15 - they still come from the MR26
% FLCA-F geometry. Open question: the user believes the geometry changed.
link_force_N          = 8140;    % max link force (N), Rev15
angle_from_normal_deg = 10.45;   % link angle from panel normal (deg) based on MR26 FLCA-F geometry (UNVERIFIED for Rev15)
bracket_type          = 'B';     % 'A' or 'B' bracket style
a                     = 1.52;    % distance between bolts (in)
y                     = 0.4185;  % spherical to middle of bracket base (in)

SF = 2;                          % safety factor applied to loads

inserts_per_bracket = 2;         % inserts (= bolts) per bracket
inserts_per_puck    = 2;         % inserts sharing one puck: 1, or = inserts_per_bracket

% How Q, M and friction are split between the inserts of one bracket:
%   'whole_bracket' = CURRENT behaviour ("method 1" of the MR26 sheet): per-insert P, but the
%                     WHOLE-bracket Q, M and friction are applied to each insert. Conservative
%                     but inconsistent with P.
%   'per_insert'    = Q and M divided by inserts_per_bracket, friction per bolt.
load_convention = 'whole_bracket';

% Friction credit. With these numbers friction (850 lb per bracket) cancels all
% shear for every control arm at SF 2-2.5. The default 2125.8 lb is a THEORETICAL
% 75%-of-proof preload; the MR26/MR25 torque-spec value for FLCA fore is 1156 lb
% with mu = 0.175. Set use_friction = false for a conservative shear check (this is
% the baseline for shear-dominated / aero hardpoints). All preload and mu values are
% UNVERIFIED assumptions.
use_friction = true;
bolt_preload = 2125.8;           % lb per bolt, 75% of proof load (old calc value)
mu           = 0.2;              % Al bracket on carbon (old calc value; sheet uses 0.175)
preload_retention = 1.0;         % fraction of preload retained (0.5 - 1.0); 1.0 = old behaviour

%% 2. SANDWICH PANEL
% This is where ply thickness and core thickness go. old calc hard-coded these
% in its CORE PROPERTIES / FACE SHEET PROPERTIES blocks (c = 0.75,
% f = 0.055); here f is built from our ply count and ply thickness.
% PLACEHOLDER: layup (plies, ply thickness, Ef) and core height are NOT confirmed
% by the composites lead; to be re-asked.

% Face sheet (one skin)
n_plies   = 3;                   % plies per face sheet  PLACEHOLDER
t_ply_mm  = .18;                 % cured ply thickness (mm)  PLACEHOLDER
f         = n_plies * t_ply_mm / 25.4;   % face sheet thickness (in)
vf        = 0.3;                 % Poisson's ratio = sqrt(vxy*vyx)
Ef        = 4.33e6;              % Young's modulus (psi) = sqrt(Ex*Ey) (SES value)  PLACEHOLDER
Sigma_fy  = 14000;               % interlaminar shear strength of skin (psi) - old calc value  PLACEHOLDER
tau_f_punch = 14000;             % skin through-thickness shear (punch) strength (psi)  PLACEHOLDER

% Core
c         = 1;                   % core height (in) PLACEHOLDER - confirm per panel
% Core selection: panel core (low density, surrounds the puck) and puck core
% (high density, pre-made patch the insert sits in). Both chosen by name from
% the library below. Change these per hardpoint / panel.
panel_core_name = '1/8-3.1';     % ASSUMED 3.1 pcf for all panels until confirmed per panel
puck_core_name  = '1/8-6.1';     % puck core (6.1 pcf, to be confirmed)
strength_basis  = 'min';         % 'min' (design value) or 'typ' for core shear strength
Gc_scale        = 1;             % sensitivity knob ONLY. Gc = G_W (scale 1). Do not use as a convention.

% Core property library: Hexcel HexWeb CR-III 5052, W direction (weakest).
% Values from CLAUDE.md. NOT checked against the datasheet of the core we
% actually buy. tauW = plate shear strength (psi), GW = W shear modulus (psi).
% Gc convention: Gc = G_W directly. v2 (Gc = 13667 = 41000/3 for 6.1 pcf) and the
% MR26 sheet used G_W/3, which has no known basis,
% is not conservative (lower Gc -> smaller radius), and is NOT used here.
% foil: gauge is blank unless stated in an earlier version of this file;
% fill in from the datasheet.
core_lib = struct( ...
  'name',    {'1/8-3.1','3/16-3.1','1/8-4.5','3/16-4.4','1/4-4.3','5/32-3.8','1/8-6.1','3/16-5.7','1/8-8.1','3/16-8.1'}, ...
  'cell_in', {1/8, 3/16, 1/8, 3/16, 1/4, 5/32, 1/8, 3/16, 1/8, 3/16}, ...
  'foil',    {'.0015 (from earlier file version)','TBC','TBC','TBC','TBC','TBC','TBC','TBC','TBC','TBC'}, ...
  'rho_pcf', {3.1, 3.1, 4.5, 4.4, 4.3, 3.8, 6.1, 5.7, 8.1, 8.1}, ...
  'tauW_min',{90, 90, 168, 160, 155, 125, 272, 244, 400, 400}, ...
  'tauW_typ',{130, 125, 220, 215, 200, 165, 340, 300, 470, 480}, ...
  'GW',      {22000, 22000, 31000, 30000, 29800, 26400, 41000, 38500, 54000, 54000});

%% 3. PLUG MATERIAL  <-- EDIT
% All values are placeholders, replace with numbers from datasheet of the
% stuff we actually buy
%   Fcu_flat: compressive strength, flatwise (load along plug axis)
%   Fbru: bearing / edgewise compressive strength (bolt pushing sideways)
%   Fsu_perp: shear strength perpendicular to laminate ("punch" shear)
%   T_max_C: glass transition / max service temp (must clear the cure)
plug_material = 'G7';

switch plug_material
    case 'G7'   % glass cloth + silicone resin
        mat.name = 'G7';      mat.rho_gcc = 1.68;
        mat.Fcu_flat = 35000; mat.Fbru = 20000; mat.Fsu_perp = 12000;
        mat.T_max_C = 220;    mat.verified = false;
    case 'G10'  % glass cloth + epoxy
        mat.name = 'G10';     mat.rho_gcc = 1.82;
        mat.Fcu_flat = 60000; mat.Fbru = 35000; mat.Fsu_perp = 19000;
        mat.T_max_C = 130;    mat.verified = false;
    case 'G11'  % glass cloth + high-temp epoxy
        mat.name = 'G11';     mat.rho_gcc = 1.82;
        mat.Fcu_flat = 60000; mat.Fbru = 35000; mat.Fsu_perp = 19000;
        mat.T_max_C = 170;    mat.verified = false;
    otherwise
        error('Unknown plug_material "%s" - add a case above.', plug_material);
end

cure_temp_F = 350;               % monocoque cure temperature (F)  <-- EDIT if you lower it

% Which insert type is carried into the puck / mass / margin reports:
%   'potted' = Al NAS03 spool potted in INF-114 + glass beads (lead concept)
%   'plug'   = machined G7 (or G10/G11) plug (still live - material availability)
insert_type = 'potted';

%% 4. BONDS
% Bond line between the insert (plug wall or potting) and the cut honeycomb,
% averaged over the full wall area (2*pi*b*c). Only the foil edges touch it, so this
% is NOT the adhesive's datasheet lap shear. Ideally test it (push-out coupons).
% Default (empty []) = core shear strength of the core the insert sits in (old calc
% implicitly assumes the core fails before the bond). NOT MEASURED.
tau_bond_allow   = [];           % psi, [] = core Twcrit  PLACEHOLDER
bond_is_measured = false;        % set true once tau_bond_allow comes from your tests
bond_knockdown   = 1.0;          % extra knockdown on the bond (1 = none)
% Puck-to-panel splice (film adhesive between the cut core edges). Reported, not sized.
tau_splice_allow = [];           % psi, [] = PANEL core Twcrit  PLACEHOLDER, NOT MEASURED

%% 5. HARDWARE AND SIZING RULES
d_bolt   = 0.190;                % bolt diameter (in), 10-32 / NAS03
d_hole   = 0.191;                % clearance hole in plug (in)
d_washer = 0.438;                % washer / nut bearing OD on the plug side (in)
eD_min   = 2.0;                  % min edge distance ratio (plug radius / hole dia)  PLACEHOLDER
b_min    = 0.25;                 % floor on radius (old calc floored at 0.25")
b_step   = 0;                    % round plug radius up to this step (in); 0 = no rounding
Pss_knockdown = 0.89;            % ECSS min-vs-typical knockdown (old calc value)
bgrid    = linspace(0.15, 4, 20000);    % candidate insert radii (in)
Rgrid    = linspace(0.15, 12, 60000);   % candidate puck radii (in)

% Puck rules (all PLACEHOLDERS)
puck_wall_min     = 0.25;        % in, min puck wall between insert edge and puck edge  PLACEHOLDER
splice_film_kgm2  = 0.3;         % kg/m^2 film adhesive areal weight on the puck wall   PLACEHOLDER
round_to_std      = true;        % build to standard sizes below (puck mass uses them)
std_sizes         = [0.50 0.625 0.75 0.875 1.00 1.25 1.50 2.00 2.50 3.00 3.50];  % in, insert radius  PROPOSED, not agreed
std_puck_R        = [2 2.5 3 3.5 4 5 6 7 8];                                      % in, puck radius    PROPOSED, not agreed

% Potted reference insert (for the mass comparison)
% Spool geometry: NAS03 Al spool, "Insert lengths 26" tab of the MR26 sheet.
% Spool length is taken as the full panel thickness (2*f + c).
spool_flange_OD  = 0.500;        % in
spool_flange_t   = 0.080;        % in, each flange
spool_neck_dia   = 0.291;        % in
spool_hole_dia   = 0.191;        % in, bolt clearance through the spool
rho_al_gcc       = 2.70;         % Al 6061 (g/cc)
% Potting compound, selected by name (see potting_lookup.m):
%   'INF-114'    : current baseline. MR26 sheet: 0.01868 kg/in^3 neat epoxy, x0.6 for
%                  glass beads = 0.01121 kg/in^3 (0.68 g/cc).  PLACEHOLDER
%   'LAM-151-HT' : Pro-Set LAM-151-HT / LAM-251-HT (datasheet Rev 6, Mar 2025), under
%                  consideration. Datasheet values are for NEAT resin; the x0.6 bead
%                  factor is ASSUMED (copied from INF-114), not measured.
potting_material = 'LAM-151-HT';             % per user (Nov 2026): switching from INF-114; set 'INF-114' for the old baseline
bead_factor      = 1.0;                      % 1.0 = UNFILLED (no glass beads, per user), so the datasheet's neat density applies.
                                             % [] = library default (0.6, the old INF-114 + beads assumption)
pot              = potting_lookup(potting_material, bead_factor);
rho_potting_gcc  = pot.rho_gcc;              % g/cc used for mass

% Spool neck compression check (neck-only; the potting shares load in reality)
sigma_cy_al   = 35000;           % psi, 6061-T6 compressive yield (design); MR25 sheet uses 40000  PLACEHOLDER
neck_preloads = [2125.8, 1156.29];   % lb: theoretical 75% proof, and FLCA-fore torque-spec value
neck_preload_names = {'theoretical 75% proof', 'torque spec FLCA fore'};

%% 6. PACK EVERYTHING INTO ONE PARAMETER STRUCT
p = struct();
p.load_mode = load_mode;  p.direct_P = direct_P;  p.direct_Q = direct_Q;  p.direct_M = direct_M;
p.link_force_N = link_force_N;  p.angle_deg = angle_from_normal_deg;
p.bracket_type = bracket_type;  p.a = a;  p.y = y;  p.SF = SF;
p.inserts_per_bracket = inserts_per_bracket;  p.inserts_per_puck = inserts_per_puck;
p.load_convention = load_convention;
p.use_friction = use_friction;  p.bolt_preload = bolt_preload;  p.mu = mu;
p.preload_retention = preload_retention;
p.f = f;  p.vf = vf;  p.Ef = Ef;  p.Sigma_fy = Sigma_fy;  p.tau_f_punch = tau_f_punch;  p.c = c;
p.core_lib = core_lib;  p.panel_core_name = panel_core_name;  p.puck_core_name = puck_core_name;
p.strength_basis = strength_basis;  p.Gc_scale = Gc_scale;
p.mat = mat;  p.insert_type = insert_type;
p.tau_bond_allow = tau_bond_allow;  p.bond_knockdown = bond_knockdown;
p.tau_splice_allow = tau_splice_allow;
p.d_bolt = d_bolt;  p.d_hole = d_hole;  p.d_washer = d_washer;  p.eD_min = eD_min;
p.b_min = b_min;  p.b_step = b_step;  p.Pss_knockdown = Pss_knockdown;
p.bgrid = bgrid;  p.Rgrid = Rgrid;
p.puck_wall_min = puck_wall_min;  p.splice_film_kgm2 = splice_film_kgm2;
p.round_to_std = round_to_std;  p.std_sizes = std_sizes;  p.std_puck_R = std_puck_R;
p.spool_flange_OD = spool_flange_OD;  p.spool_flange_t = spool_flange_t;
p.spool_neck_dia = spool_neck_dia;  p.spool_hole_dia = spool_hole_dia;
p.rho_al_gcc = rho_al_gcc;  p.rho_potting_gcc = rho_potting_gcc;
p.sigma_cy_al = sigma_cy_al;  p.neck_preloads = neck_preloads;

%% 7. SOLVE
r = size_hardpoint(p);
if ~r.ok
    error('%s Loads too high for this panel.', r.msg);
end
L   = r.L;   leg = r.leg;   pk = r.pk;   sel = r.sel;
P = L.P;  Q = L.Q;  M = L.M;
F = L.F;
panel = r.panel;  puck = r.puck;
Sc = r.cp_panel.Sc;  Gc = r.cp_panel.Gc;  Twcrit = r.cp_panel.Twcrit;
max_friction = L.max_friction;

%% 8. RESULTS: LOADS AND CORES
fprintf('\n=== DESIGN LOADS PER INSERT (SF = %.2f) ===\n', SF);
if strcmpi(load_mode, 'bracket')
    fprintf('Link force %.0f N (%.0f lb), %.2f deg from normal, bracket type %s\n', ...
            link_force_N, F, angle_from_normal_deg, upper(bracket_type));
else
    fprintf('DIRECT load input per insert (before SF): P = %.0f lb, Q = %.0f lb, M = %.0f lb-in, no friction credit\n', ...
            direct_P, direct_Q, direct_M);
end
fprintf('P = %.0f lb   Q = %.0f lb   M = %.0f lb-in   (friction credit %.0f lb)\n', P, Q, M, max_friction);
fprintf('Panel: f = %.4f in (%d plies x %.3f mm), c = %.3f in   [layup and c are UNVERIFIED placeholders]\n', f, n_plies, t_ply_mm, c);
fprintf('Panel core: %s (%.1f pcf, cell %.4f in), tau_W %s = %.0f psi, Gc = G_W = %.0f psi (no /3)\n', ...
        panel.name, panel.rho_pcf, Sc, strength_basis, Twcrit, Gc);
fprintf('Puck core selected: %s (%.1f pcf, tau_W min %.0f psi, G_W %.0f psi)\n', ...
        puck.name, puck.rho_pcf, puck.tauW_min, puck.GW);
fprintf('  UNVERIFIED: core data from CLAUDE.md Hexcel table, panel core ASSUMED 3.1 pcf, foil gauge not populated\n');
fprintf('Load convention: %s  (%d inserts per bracket, %d per puck)\n', load_convention, inserts_per_bracket, inserts_per_puck);
if strcmpi(load_mode, 'bracket') && use_friction
    fprintf('  Friction credit: %d bolts x %.0f lb x mu %.3f x retention %.2f  [preload and mu UNVERIFIED]\n', ...
            inserts_per_bracket, bolt_preload, mu, preload_retention);
end
if strcmpi(load_mode, 'bracket')
    fprintf('  Q before friction = %.0f lb (whole bracket, SF applied)\n', L.Q_before_friction);
end

%% 9. RESULTS: LEGACY (no puck, insert sized directly in the PANEL core)
% This section reproduces the original script's output.
fprintf('\n=== POTTED REFERENCE INSERT (old calc method) ===\n');
fprintf('Required potting radius by failure mode:\n');
for k = 1:numel(leg.pot_vals)
    tag = '';  if k == leg.igov_pot, tag = '  <-- governs'; end
    fprintf('  %-40s %6.3f in%s\n', leg.pot_names{k}, leg.pot_vals(k), tag);
end
fprintf('Real potting radius: %.3f in  (old calc alone would give %.3f in)\n', leg.bp_potted, max(leg.bp_ecss, b_min));
fprintf('Mass: %.1f g total = %.1f g Al spool (%.4f in^3, %.3f in long) + %.1f g potting (%.3f in^3)\n', ...
        1000*leg.mass.potted, 1000*leg.mass.spool, leg.mass.V_spool, leg.mass.L_spool, 1000*leg.mass.potting, leg.mass.V_potting);

fprintf('\n=== %s PLUG: REQUIRED RADIUS BY FAILURE MODE ===\n', mat.name);
for k = 1:numel(leg.req_vals)
    tag = '';  if k == leg.igov, tag = '  <-- governs'; end
    fprintf('  %-40s %6.3f in%s\n', leg.req_names{k}, leg.req_vals(k), tag);
end
fprintf('Plug radius to machine: %.4f in (dia %.4f in), approx. mass %.1f g\n', ...
        leg.b_design, 2*leg.b_design, 1000*leg.mass.plug);

mp = leg.m_plug;
fprintf('\n=== PLUG-TO-CORE BOND REQUIREMENT (target for push-out coupons) ===\n');
fprintf('  Bond must carry >= %.0f psi  (= P / (2*pi*b*c), all load through the wall)\n', mp.tau_bond_req);
if bond_is_measured
    src = 'measured';
else
    src = 'core shear strength, not measured';
end
fprintf('  Current allowable %.0f psi (%s) -> MS = %.2f\n', mp.tau_bond_allow, src, mp.bond);
fprintf('  For a coupon of radius r and core height h: pass if failure load > %.0f*2*pi*r*h lb\n', mp.tau_bond_req);

fprintf('\n=== OTHER %s CHECKS (margin of safety, >0 passes) ===\n', mat.name);
fprintf('  Washer crush (flatwise)      MS = %6.2f\n', mp.washer);
fprintf('  Bolt bearing in plug         MS = %6.2f  (no friction, plug alone)\n', mp.bearing);
fprintf('  Washer punch-through plug    MS = %6.2f\n', mp.punchthru);
T_cure_C = (cure_temp_F-32)*5/9;
if mat.T_max_C < T_cure_C
    fprintf('  WARNING: %s max temp %.0f C is below the %.0f C (%.0f F) cure.\n', ...
            mat.name, mat.T_max_C, T_cure_C, cure_temp_F);
end
if ~mat.verified
    fprintf('\n  NOTE: %s material properties are still PLACEHOLDERS.\n', mat.name);
end
if ~bond_is_measured
    fprintf('  NOTE: bond allowable = core shear strength (%.0f psi), not measured.\n', mp.tau_bond_allow);
end
if leg.qss_extrapolated
    fprintf('  NOTE: Q > 0 and the radius is above 0.433 in: the Qss fit (valid for bp < 0.433 in) is EXTRAPOLATED.\n');
end

%% 10. RESULTS: TWO-LEVEL PUCK DESIGN
% Insert radius b is sized in the PUCK core (existing failure-mode breakdown); puck radius R is
% sized by treating the puck as one large rigid insert in the PANEL core that carries the load of
% all inserts in it. Bonds are REPORTED as required strengths, not sized.
fprintf('\n=============================================================\n');
fprintf('=== TWO-LEVEL DESIGN: INSERT IN PUCK (%s), PUCK IN PANEL (%s) ===\n', puck.name, panel.name);
fprintf('=============================================================\n');
fprintf('Loads on the puck (%d insert(s)): P = %.0f lb, Q = %.0f lb, M = %.0f lb-in\n', ...
        inserts_per_puck, L.Ppk, L.Qpk, L.Mpk);
fprintf('\nInsert radius in PUCK core by failure mode (potted, then %s plug):\n', mat.name);
for k = 1:numel(pk.pot_vals)
    tag = '';  if k == pk.igov_pot, tag = '  <-- governs'; end
    fprintf('  potted: %-40s %6.3f in%s\n', pk.pot_names{k}, pk.pot_vals(k), tag);
end
for k = 1:numel(pk.req_vals)
    tag = '';  if k == pk.igov, tag = '  <-- governs'; end
    fprintf('  plug  : %-40s %6.3f in%s\n', pk.req_names{k}, pk.req_vals(k), tag);
end
if isfinite(r.R_ecss)
    fprintf('\nPuck radius from ECSS core shear in the PANEL core (rigid insert of radius R): R = %.3f in\n', r.R_ecss);
else
    fprintf('\nPuck radius: NO SOLUTION below %.0f in in the PANEL core for these loads.\n', max(Rgrid));
end
types = {'potted', 'plug'};
for k = 1:2
    t = r.t.(types{k});
    if strcmp(types{k}, 'potted'), nm = 'Potted spool'; else, nm = [mat.name ' plug']; end
    fprintf('\n--- %s in puck ---\n', nm);
    fprintf('  Insert radius needed %.3f in -> standard size %.3f in%s\n', t.b_exact, t.b_ab, ...
            ternary_str(t.b_beyond, '  (beyond the standard list, rounded up)', ''));
    fprintf('  Puck radius: ECSS %.3f in, geometry (offset %.3f + b + wall %.3f) %.3f in -> R = %.3f in, standard %.3f in%s\n', ...
            r.R_ecss, r.offset, puck_wall_min, t.R_geom, t.R_req, t.R_ab, ...
            ternary_str(t.R_geom_governs, '  (geometry governs)', ''));
    fprintf('  Geometric check b + wall (+ offset) <= R:   MS = %6.2f\n', t.geom_ms);
    fprintf('  Puck ECSS interaction at R (panel core):    MS = %6.2f\n', t.puck_ecss_ms);
    fprintf('  Bond REQUIRED (reported, not sized): insert-to-puck %.0f psi (allow %.0f psi, MS %.2f);  splice at R %.0f psi (allow %.0f psi, MS %.2f)\n', ...
            t.m.tau_bond_req, t.m.tau_bond_allow, t.m.bond, t.tau_splice_req, t.tau_splice_allow, t.splice_ms);
    fprintf('  Net mass: %.0f g per puck (puck core %.0f + film %.0f + inserts %.0f - panel core removed %.0f)\n', ...
            1000*t.mass.net, 1000*t.mass.puck_core, 1000*t.mass.film, 1000*t.mass.inserts, 1000*t.mass.displaced);
end
fprintf('\n  Selected insert type for reports below: %s\n', insert_type);
fprintf('  UNVERIFIED: puck wall %.2f in, film %.2f kg/m^2, standard size lists, bond and splice allowables (= core Twcrit), tau_f_punch.\n', ...
        puck_wall_min, splice_film_kgm2);

% In-plane capacity breakdown
fprintf('\n=== IN-PLANE CAPACITY Qss (core + skin contributions) ===\n');
fprintf('  Qss = 8*b^2*tau_W (core, PLATE SHEAR strength, not crush) + 2*f*b*sigma_fy (skin; sigma_fy %.0f psi is a PLACEHOLDER)\n', Sigma_fy);
for k = 1:2
    if k == 1, cc = r.cp_panel; lab = 'panel core'; else, cc = r.cp_puck; lab = 'puck core'; end
    bx = f*Sigma_fy/(4*cc.Twcrit);
    if k == 1, bb = leg.bp_potted; else, bb = sel.b_ab; end
    core_t = 8*bb^2*cc.Twcrit;  skin_t = 2*f*bb*Sigma_fy;
    if core_t > skin_t, dom = 'core term dominates'; else, dom = 'skin term dominates'; end
    fprintf('  %-10s (%s, tau_W %.0f psi): equal at b = %.2f in; at b = %.3f in core %.0f lb vs skin %.0f lb -> %s\n', ...
            lab, cc.name, cc.Twcrit, bx, bb, core_t, skin_t, dom);
end
fprintf('  The Qss fit is only valid for bp < 0.433 in (v2 comment); at current sizes the Q term is EXTRAPOLATED');
if Q <= 0
    fprintf(' (Q = 0 here, so it does not enter).\n');
else
    fprintf(' (Q = %.0f lb enters).\n', Q);
end

%% 11. FRICTION CREDIT, BOTH WAYS
if run_friction_table
    fprintf('\n=== FRICTION CREDIT: WITH AND WITHOUT (all preloads and mu are UNVERIFIED assumptions) ===\n');
    scen = {'No friction credit (aero / shear baseline)', false,    0,       0,     1.0; ...
            'Torque spec 1156 lb, mu 0.175, retained 100%', true, 1156.29, 0.175, 1.0; ...
            'Torque spec 1156 lb, mu 0.175, retained 50%',  true, 1156.29, 0.175, 0.5; ...
            'Theoretical 2126 lb, mu 0.2,   retained 100%', true, 2125.8,  0.2,   1.0; ...
            'Theoretical 2126 lb, mu 0.2,   retained 50%',  true, 2125.8,  0.2,   0.5};
    fprintf('  %-46s %7s | %-24s | %-24s | %8s\n', 'Scenario', 'Q (lb)', 'no puck: potted / plug', 'in puck: potted / plug', 'puck R');
    for k = 1:size(scen, 1)
        pp = p;  pp.use_friction = scen{k,2};  pp.bolt_preload = scen{k,3};  pp.mu = scen{k,4};  pp.preload_retention = scen{k,5};
        rr = size_hardpoint(pp);
        if rr.ok
            fprintf('  %-46s %7.0f | %9.3f / %-12.3f | %9.3f / %-12.3f | %8.3f\n', scen{k,1}, rr.L.Q, ...
                    rr.leg.bp_potted, rr.leg.b_design, rr.pk.bp_potted, rr.pk.b_design, rr.R_ecss);
        else
            fprintf('  %-46s %s\n', scen{k,1}, rr.msg);
        end
    end
    fprintf('  (radii in inches, exact, before rounding to standard sizes; Q > 0 means the Qss fit is extrapolated above 0.433 in)\n');
end

%% 12. LOAD SPLIT CONVENTION: CURRENT vs PER-INSERT
if run_convention_table
    fprintf('\n=== LOAD CONVENTION IMPACT (current default: %s) ===\n', load_convention);
    fprintf('  whole_bracket: P = SF*Fn/n per insert, but Q = SF*Fs - friction and M = SF*Fs*y are WHOLE-bracket on each insert.\n');
    fprintf('  per_insert   : the same P, with Q and M divided by n = %d and friction taken per bolt.\n', inserts_per_bracket);
    conv = {'whole_bracket', 'per_insert'};
    for fr = [1 0]
        for k = 1:2
            pp = p;  pp.load_convention = conv{k};  pp.use_friction = logical(fr);
            rr = size_hardpoint(pp);
            if rr.ok
                fprintf('  friction %-3s %-13s P=%5.0f Q=%5.0f M=%5.0f | no puck potted %.3f in, plug %.3f in | in puck potted %.3f in, plug %.3f in | puck R %.3f in\n', ...
                        ternary_str(fr, 'on', 'off'), conv{k}, rr.L.P, rr.L.Q, rr.L.M, rr.leg.bp_potted, rr.leg.b_design, ...
                        rr.pk.bp_potted, rr.pk.b_design, rr.R_ecss);
            end
        end
    end
    fprintf('  (puck R uses bracket-level resultants either way; only the per-insert sizing changes with the convention)\n');
end

%% 13. SPOOL NECK COMPRESSION (potted spool only)
fprintf('\n=== SPOOL NECK COMPRESSION (neck-only check, push-in load P = %.0f lb) ===\n', P);
mn = pk.m_pot;
fprintf('  Neck %.3f in OD, %.3f in bore, area %.4f in^2; 6061-T6 compressive yield %.0f psi (PLACEHOLDER; MR25 sheet uses 40 ksi)\n', ...
        spool_neck_dia, spool_hole_dia, mn.A_neck, sigma_cy_al);
for k = 1:numel(neck_preloads)
    fprintf('  Preload %7.1f lb (%-22s): preload alone %.1f ksi; with P %.1f ksi -> MS = %6.2f %s\n', ...
            neck_preloads(k), neck_preload_names{k}, neck_preloads(k)/mn.A_neck/1000, mn.neck_sigma(k)/1000, mn.neck(k), ...
            ternary_str(mn.neck(k) < 0, 'FAIL', 'pass'));
end
fprintf('  A neck-only FAIL is the KNOWN result, not a bug: in the real part the potting shares the compression. Flagged in the DR2 slides.\n');

%% 13b. POTTING MATERIAL
fprintf('\n=== POTTING MATERIAL: %s (source: %s) ===\n', pot.name, pot.source);
if pot.bead_factor == 1
    fprintf('  Density used for mass: %.3f g/cc = neat resin, UNFILLED (no glass beads), datasheet value\n', pot.rho_gcc);
else
    fprintf('  Density used for mass: %.3f g/cc = neat %.3f g/cc x bead factor %.2f  [bead factor is an ASSUMPTION, not measured]\n', ...
            pot.rho_gcc, pot.rho_neat_gcc, pot.bead_factor);
end
fprintf('  Compressive yield %.0f psi: %s\n', pot.comp_yield_psi, pot.comp_note);
if ~isnan(pot.Tg_onset_F)
    fprintf('  Thermal: %s\n', pot.Tg_note);
    if cure_temp_F > pot.Tg_onset_F
        fprintf('  NOTE: the %.0f F monocoque cure is above the datasheet post-cure schedules (<= 302 F). Expect it to fully cure it, but\n', cure_temp_F);
        fprintf('        there is no datasheet data at 350 F, and pot life / gel behaviour on the way up to cure is unchecked.\n');
    end
end
fprintf('  Mix: %s\n', pot.mix);
fprintf('  UNVERIFIED: properties after the 350 F co-cure (datasheet cures stop at 302 F), and the neat compressive yield is used as-is. The potting strength is not used in any check above.\n');
fprintf('  Comparison, potted spool in puck (everything else unchanged):\n');
cmp = {'INF-114 + glass beads (old baseline)', 'INF-114',    [];  ...
       'LAM-151-HT + glass beads (x0.6 assumed)', 'LAM-151-HT', 0.6; ...
       'LAM-151-HT unfilled',                  'LAM-151-HT', 1.0};
for k = 1:size(cmp, 1)
    pk_pot = potting_lookup(cmp{k,2}, cmp{k,3});
    pp = p;  pp.rho_potting_gcc = pk_pot.rho_gcc;
    rr = size_hardpoint(pp);
    if rr.ok
        fprintf('    %-42s %.3f g/cc: potting+spool %.0f g per insert, %.0f g net per bracket (incl. puck)\n', ...
                cmp{k,1}, pk_pot.rho_gcc, 1000*rr.t.potted.mass.ins.potted, 1000*rr.t.potted.mass.net_per_bracket);
    end
end

%% 14. MASS
fprintf('\n=== MASS (per puck and per insert, net of the panel core displaced) ===\n');
for k = 1:2
    t = r.t.(types{k});
    if strcmp(types{k}, 'potted'), nm = 'Potted spool'; else, nm = [mat.name ' plug']; end
    fprintf('  %-12s in puck: %.0f g per puck gross (%.0f net), %.0f g net per insert, %.0f g net per bracket\n', ...
            nm, 1000*t.mass.gross, 1000*t.mass.net, 1000*t.mass.net_per_insert, 1000*t.mass.net_per_bracket);
end
pr = r.t.plug.mass.inserts / r.t.potted.mass.inserts;
fprintf('  Insert-only mass ratio plug / potted at their own radii = %.2f (plug %.2f g/cc vs potting %.2f g/cc: %.2fx at the SAME radius, ignoring the spool)\n', ...
        pr, mat.rho_gcc, rho_potting_gcc, mat.rho_gcc/rho_potting_gcc);
Vleg = pi*leg.bp_potted^2*c;  mdisp = panel.rho_pcf*0.0160185*16.387064/1000*Vleg;
fprintf('  No-puck potted insert (r = %.2f in in %s core): %.0f g gross, %.0f g net of the core it displaces\n', ...
        leg.bp_potted, panel.name, 1000*leg.mass.potted, 1000*(leg.mass.potted - mdisp));
fprintf('  Car-level totals come from the batch table (section 17).\n');

%% 15. MARGIN-OF-SAFETY TABLE AT THE STANDARD SIZE
fprintf('\n=== MARGIN OF SAFETY AT STANDARD SIZE (>0 passes) ===\n');
for k = 1:2
    t = r.t.(types{k});
    fprintf('  %s in puck: insert radius %.3f in, puck R %.3f in\n', types{k}, t.b_ab, t.R_ab);
    for j = 1:numel(t.m.names)
        fprintf('    %-52s MS = %7.2f\n', t.m.names{j}, t.m.vals(j));
    end
    fprintf('    %-52s MS = %7.2f\n', 'Puck ECSS interaction at R (panel core, 1 - sum sq)', t.puck_ecss_ms);
    fprintf('    %-52s MS = %7.2f\n', 'Puck splice bond (placeholder allowable)', t.splice_ms);
    fprintf('    %-52s MS = %7.2f\n', 'Geometry: b + wall (+ offset) <= R', t.geom_ms);
end
fprintf('  ECSS and puck-ECSS margins are 1 - (sum of squares); the rest are capacity/demand - 1. Not directly comparable.\n');
fprintf('  Margins marked with placeholders: punch (tau_f_punch), bond/splice (allowable = core Twcrit), plug checks (%s properties).\n', mat.name);

%% 16. SENSITIVITY SWEEPS ON THE UNMEASURED INPUTS
if run_sensitivity
    fprintf('\n=== SENSITIVITY (selected insert: %s in puck; one input varied at a time) ===\n', insert_type);
    fprintf('  columns: insert radius needed | puck R needed | insert-to-puck bond MS | net mass per bracket\n');
    fprintf('  Swept with friction credit OFF (shear baseline, Q = full shear) so Sigma_fy matters; the preload sweep turns friction ON.\n');
    sens = {'tau_f_punch (psi)',          'tau_f_punch',      [7000 10500 14000 21000], false; ...
            'Sigma_fy (psi)',             'Sigma_fy',         [7000 10500 14000 21000], false; ...
            'tau_bond_allow (psi)',       'tau_bond_allow',   [50 90 150 272],          false; ...
            'Gc scale (1 = G_W, 1/3 = old /3)', 'Gc_scale',   [1/3 0.5 1],              false; ...
            'potting density (g/cc)',     'rho_potting_gcc',  [0.68 0.9 1.13 1.4],      false; ...
            'bolt preload (lb), friction ON, mu 0.175', 'bolt_preload', [0 500 1156.29 2125.8], true};
    for k = 1:size(sens, 1)
        fprintf('  %s\n', sens{k,1});
        for v = sens{k,3}
            pp = p;
            pp.use_friction = false;
            pp.(sens{k,2}) = v;
            if sens{k,4}, pp.use_friction = true;  pp.mu = 0.175;  pp.preload_retention = 1.0; end
            rr = size_hardpoint(pp);
            if rr.ok
                ss = rr.sel;
                fprintf('    %10.4g : b %.3f in | R %.3f in | bond MS %6.2f | %.0f g\n', v, ss.b_exact, ss.R_req, ss.m.bond, 1000*ss.mass.net_per_bracket);
            else
                fprintf('    %10.4g : %s\n', v, rr.msg);
            end
        end
    end
    fprintf('  Potting radius +/- 0.125 in (cleared-cell process variation), potted spool in puck:\n');
    tp = r.t.potted;
    for dr = [-0.125 0 0.125]
        bb = tp.b_ab + dr;
        mm = insert_margins(p, 'potted', r.cp_puck, P, Q, M, L.Q_bearing, bb);
        im = insert_mass(p, bb, bb);
        fprintf('    bp = %.3f in : ECSS MS %6.2f | punch MS %6.2f | bond MS %6.2f | potting+spool %.0f g\n', ...
                bb, mm.ecss, mm.punch, mm.bond, 1000*im.potted);
    end
end

%% 17. BATCH RUN OVER A HARDPOINT TABLE
if run_batch && exist(hardpoint_csv, 'file')
    hp = read_hardpoint_csv(hardpoint_csv);
    fprintf('\n=== BATCH: %d hardpoints from %s (%s) ===\n', numel(hp), hardpoint_csv, insert_type);
    fprintf('  GEOMETRY of every row except FLCA fore is a PLACEHOLDER (FLCA-F values reused) - totals are INDICATIVE ONLY.\n');
    fprintf('  %-20s %5s %5s %5s %5s | %7s %7s | %6s %6s | %7s | %s\n', 'hardpoint', 'qty', 'P', 'Q', 'M', 'b_ins', 'b_std', 'R_req', 'R_std', 'g/brkt', 'governs / flags');
    tot_net = 0;  tot_gross = 0;  tot_ins = 0;  tot_brk = 0;
    std_b_all = [];  std_b_cnt = [];  std_R_all = [];  std_R_cnt = [];
    for i = 1:numel(hp)
        pp = p;
        flds = fieldnames(hp);
        for j = 1:numel(flds)
            switch flds{j}
                case 'name', continue
                case {'qty', 'geom_verified'}, continue
                case 'angle_deg', pp.angle_deg = hp(i).angle_deg;
                case 'panel_core', pp.panel_core_name = hp(i).panel_core;
                case 'puck_core',  pp.puck_core_name  = hp(i).puck_core;
                case 'use_friction', pp.use_friction = logical(hp(i).use_friction);
                otherwise, pp.(flds{j}) = hp(i).(flds{j});
            end
        end
        rr = size_hardpoint(pp);
        flag = '';
        if ~hp(i).geom_verified, flag = [flag ' GEOM-PLACEHOLDER']; end %#ok<AGROW>
        if ~rr.ok
            fprintf('  %-20s %5d  NO SOLUTION: %s%s\n', hp(i).name, hp(i).qty, rr.msg, flag);
            continue
        end
        ss = rr.sel;
        if strcmp(pp.insert_type, 'potted')
            govnames = rr.pk.pot_names;  govi = rr.pk.igov_pot;
        else
            govnames = rr.pk.req_names;  govi = rr.pk.igov;
        end
        gov = govnames{govi};
        if rr.pk.qss_extrapolated, flag = [flag ' Qss-extrapolated']; end %#ok<AGROW>
        if ss.R_geom_governs, flag = [flag ' R-by-geometry']; end %#ok<AGROW>
        fprintf('  %-20s %5d %5.0f %5.0f %5.0f | %7.3f %7.3f | %6.2f %6.2f | %7.0f | %s;%s\n', hp(i).name, hp(i).qty, ...
                rr.L.P, rr.L.Q, rr.L.M, ss.b_exact, ss.b_ab, ss.R_req, ss.R_ab, 1000*ss.mass.net_per_bracket, gov, flag);
        tot_net   = tot_net   + hp(i).qty*ss.mass.net_per_bracket;
        tot_gross = tot_gross + hp(i).qty*ss.mass.gross_per_bracket;
        tot_ins   = tot_ins   + hp(i).qty*pp.inserts_per_bracket;
        tot_brk   = tot_brk   + hp(i).qty;
        if hp(i).qty > 0
            [std_b_all, std_b_cnt] = tally(std_b_all, std_b_cnt, ss.b_ab, hp(i).qty*pp.inserts_per_bracket);
            [std_R_all, std_R_cnt] = tally(std_R_all, std_R_cnt, ss.R_ab, hp(i).qty*pp.inserts_per_bracket/pp.inserts_per_puck);
        end
    end
    fprintf('\n  Standard insert sizes used (radius in : count of inserts):');
    for k = 1:numel(std_b_all), fprintf('  %.3f : %d', std_b_all(k), std_b_cnt(k)); end
    fprintf('\n  Standard puck sizes used  (radius in : count of pucks):  ');
    for k = 1:numel(std_R_all), fprintf('  %.2f : %d', std_R_all(k), std_R_cnt(k)); end
    fprintf('\n  Car total (%d brackets, %d inserts): %.2f kg net of displaced panel core, %.2f kg gross (puck + film + inserts)\n', ...
            tot_brk, tot_ins, tot_net, tot_gross);
    fprintf('  Earlier estimates for comparison: ~3.36 kg (puck + spool concept), 2.58 kg (MR26 baseline). NOT tuned to match.\n');
    fprintf('  A gap is expected and not an error: this total uses placeholder geometry/inserts per hardpoint, standard-size rounding,\n');
    fprintf('  Gc = G_W (not /3), the SF-2 loads from the current script, and ALL pucks sharing 2 inserts. Compare insert counts and radii first.\n');
elseif run_batch
    fprintf('\n(batch skipped: %s not found in the current folder)\n', hardpoint_csv);
end

%% 18. PLOT (legacy no-puck check)
if make_plots
    figure;
    plot(leg.ecss_plug.b, leg.ecss_plug.MS, 'r', 'LineWidth', 2); hold on;
    plot(leg.ecss_pot.b_eff, leg.ecss_pot.MS, 'b--', 'LineWidth', 1.5);
    plot(leg.b_ecss, 0, 'ro', 'MarkerFaceColor', 'r');
    plot(leg.bp_ecss, 0, 'bo', 'MarkerFaceColor', 'b');
    yline(0, 'k:');
    xlim([0 2]); ylim([-1 1]);
    xlabel('Radius (in)'); ylabel('Margin of safety (ECSS core shear)');
    legend([mat.name ' plug'], 'Potted (old calc)', 'Location', 'southeast');
    title(sprintf('Link %.0f N, SF %.1f, panel core %s', link_force_N, SF, panel.name));
    grid on;
end
