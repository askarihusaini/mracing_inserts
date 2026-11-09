%% MR27 RESIN PUCK CALCULATOR (Al spool cast in a resin puck, spliced into the panel core)
% Design (Nov 2026): the global panel core is 6.1 pcf, so there is no higher-density core
% patch. Each insert is an NAS03 Al spool cast in a PRO-SET LAM-151-HT resin puck in a jig and
% fully cured. The puck is then spliced into the panel core with 3M AF 3074 core splice film
% and co-cured with the panel at 350 F.
%
% OUTPUT: (1) the resin puck radius to mold, (2) the bond strength the AF 3074 splice must provide.
%
% The puck is sized as ONE rigid round insert of radius R in the PANEL core carrying the loads of
% the spool(s) it holds (ECSS core-shear interaction, unchanged equations from ecss_core.m), plus
% face-sheet punch-out and a geometric floor (spool flange + resin wall). The two spools of a
% bracket can share ONE round puck (puck_layout = 'shared', default) or have a puck each
% ('separate', with a spacing check). The splice bond is REPORTED as a required strength, not
% sized. Loads use the same link force + bracket FBD / direct-input logic as
% G7_Insert_Calculator_MR27.m (hardpoint_loads.m).
%
% Files used: resin_puck_size.m, ecss_core.m, hardpoint_loads.m, insert_mass.m, core_lookup.m,
%             core_library.m, potting_lookup.m, splice_lookup.m, read_hardpoint_csv.m, tally.m,
%             ternary_str.m, hardpoints_MR27_resin_puck.csv
%
% VALIDATION STATUS: nothing here is validated for a SPLICED puck. The only test calibration in
% the project (MR25 Instron) is axial pull-out of cleared-cell POTTED inserts. Nothing in-plane is
% calibrated, and the splice film joint has no test data. Every value marked PLACEHOLDER is unverified.

clear; close all; clc;

%% 0. RUN OPTIONS
make_plots      = true;     % set false for headless runs
run_sensitivity = true;
run_batch       = true;
hardpoint_csv   = 'hardpoints_MR27_resin_puck.csv';

%% 1. LOADS
% load_mode: 'bracket' = link force + bracket FBD, 'direct' = enter P, Q, M per spool yourself
% (aero / non-suspension brackets; SF applied below, no friction credit).
load_mode = 'bracket';
direct_P = 0;                    % lb
direct_Q = 0;                    % lb
direct_M = 0;                    % lb-in

% Default is the worst load case (FLCA fore, Cornering 3) from MR27 Suspension Loads Rev15.
% Rev15 contains forces only: angle, a and y still come from the MR26 FLCA-F geometry and
% were NOT re-checked (user believes the geometry changed; open question).
link_force_N          = 8140;    % max link force (N), Rev15
angle_from_normal_deg = 10.45;   % deg from panel normal  UNVERIFIED for Rev15
bracket_type          = 'B';     % 'A' or 'B'
a                     = 1.52;    % distance between bolts (in)  UNVERIFIED for Rev15
y                     = 0.4185;  % spherical to middle of bracket base (in)  UNVERIFIED for Rev15
SF                    = 2;       % safety factor applied to loads
inserts_per_bracket   = 2;       % spools (= bolts) per bracket
% Puck layout (user, Nov 2026: two bolts CAN share a puck):
%   'shared'   = one ROUND puck holds both spools (at +/- a/2); loads = bracket resultants
%   'separate' = one puck per spool; neighbouring pucks must fit at the bolt spacing a
puck_layout           = 'shared';

% Split of Q, M and friction between the spools of a bracket:
%   'whole_bracket' = "method 1" of the MR26 sheet: per-insert P, but WHOLE-bracket Q, M and
%                     friction on each insert. Conservative, inconsistent with P (current default).
%   'per_insert'    = Q and M divided by inserts_per_bracket, friction per bolt.
load_convention = 'whole_bracket';

% Friction credit. Default preload is a THEORETICAL 75%-of-proof value; the MR26 torque-spec value
% for FLCA fore is 1156 lb with mu = 0.175. Both are UNVERIFIED assumptions. With these numbers
% friction cancels all shear. Set use_friction = false for the conservative / aero baseline.
use_friction      = true;
bolt_preload      = 2125.8;      % lb per bolt
mu                = 0.2;
preload_retention = 1.0;         % 0.5 - 1.0

%% 2. PANEL
% PLACEHOLDER: layup (plies, ply thickness, Ef) is not confirmed by the composites lead (user will
% ask again). Core height c = 1 in is confirmed by the user (Nov 2026).
n_plies     = 3;                 % plies per face sheet  PLACEHOLDER
t_ply_mm    = 0.18;              % cured ply thickness (mm)  PLACEHOLDER
f           = n_plies*t_ply_mm/25.4;   % face sheet thickness (in)
vf          = 0.3;
Ef          = 4.33e6;            % psi  PLACEHOLDER
Sigma_fy    = 14000;             % skin interlaminar shear strength (psi), old calc value  PLACEHOLDER
tau_f_punch = 14000;             % skin through-thickness shear (punch) strength (psi)  PLACEHOLDER
c           = 1;                 % core height (in), confirmed by the user

% Panel core: GLOBAL 6.1 pcf (per user, Nov 2026). Hexcel CR-III 5052 values from core_library.m,
% NOT checked against the datasheet of the core actually bought. Gc = G_W (no /3).
panel_core_name = '1/8-6.1';
strength_basis  = 'min';         % 'min' (design) or 'typ' core plate shear strength
Gc_scale        = 1;             % sensitivity knob ONLY. Do not use as a convention.
core_lib        = core_library();

%% 3. RESIN (puck) AND SPOOL
% Resin: Pro-Set LAM-151-HT, UNFILLED (no glass beads), cured in a jig before splicing.
% Datasheet (Rev 6, Mar 2025) values are neat resin: 1.13 g/cc. See potting_lookup.m.
potting_material = 'LAM-151-HT';
bead_factor      = 1.0;          % 1.0 = unfilled
pot              = potting_lookup(potting_material, bead_factor);
rho_potting_gcc  = pot.rho_gcc;

% Spool: NAS03 Al spool, "Insert lengths 26" tab of the MR26 sheet. Length = full panel thickness.
spool_flange_OD = 0.500;         % in
spool_flange_t  = 0.080;         % in, each flange
spool_neck_dia  = 0.291;         % in
spool_hole_dia  = 0.191;         % in, bolt clearance
rho_al_gcc      = 2.70;          % Al 6061 (g/cc)
d_hole          = 0.191;         % in

%% 4. SPLICE (3M AF 3074 FST core splice film) AND PUCK INSET
% Datasheet values (preliminary TDS, June 2025; typical, not for specification) come from
% splice_lookup.m. The film version (30 or 50 mil) is NOT decided: 50 mil assumed.
splice_film_name = 'AF3074-50mil';
splice           = splice_lookup(splice_film_name);
splice_film_kgm2 = splice.areal_kgm2;   % kg/m^2 applied film weight on the hole wall (datasheet)

% Splice ALLOWABLE shear (psi, on the full wall area). The datasheet only has tube shear on SOLID
% aluminum tubes (1883 psi at 73 F, 257 F cure) - it is NOT a honeycomb value. Choose the basis:
%   'core'       = panel core plate shear strength (assumes the core fails before the splice) [default, PLACEHOLDER]
%   'foil_edge'  = tube shear x core solidity (only the foil edges bonded): a LOWER bound
%   'tube_shear' = 1883 psi, solid-Al tube shear: an UPPER bound
%   or a number (psi) from your push-out coupon tests.
% All three are always printed as a bracket. NOT measured for honeycomb.
splice_allow_basis = 'core';
splice_knockdown   = 1.0;        % extra knockdown on the splice allowable (1 = none)
splice_gap_in      = 0.0;        % radial gap between puck and core hole that the foamed film fills (in)  PLACEHOLDER (process, not in datasheet)
cure_temp_F        = 350;        % co-cure temperature (F)

% Resin inset: the spool flanges are flush with the skins and the resin is inset slightly so it
% fits under the skins (user). The inset VALUE is not known: 0 = resin as tall as the core.
% Resin / splice wall height = c - 2*inset.
inset_each_face_in = 0.0;        % in  PLACEHOLDER (per face; TBC)

%% 5. SIZING RULES
% ECSS convention for the puck in the panel core:
%   'plug'   = rigid puck of radius R bonded on its wall (default, confirmed by the user: the resin
%              does not fill the cells; same as the Oct puck approach)
%   'potted' = v2 cleared-cell convention, bp = b + 0.35*Sc, Mss uses b (the MR25-tested geometry)
ecss_variant  = 'plug';
Pss_knockdown = 0.89;            % ECSS min-vs-typical knockdown (old calc value)
b_min         = 0.25;            % floor on the puck radius (old calc floor)
resin_wall_min = 0.125;          % in, min resin wall around the spool flange  PLACEHOLDER
min_ligament  = 0.25;            % in, min core ligament between neighbouring pucks  PLACEHOLDER
round_to_std  = true;            % mold to standard sizes (jig radii)
std_puck_R    = [0.50 0.625 0.75 0.875 1.00 1.125 1.25 1.375 1.50 1.75 2.00 2.25 2.50 3.00];  % in  PROPOSED, not agreed
bgrid         = linspace(0.15, 4, 20000);   % candidate radii (in)

%% 6. PACK PARAMETERS AND SOLVE
p = struct();
p.load_mode = load_mode;  p.direct_P = direct_P;  p.direct_Q = direct_Q;  p.direct_M = direct_M;
p.link_force_N = link_force_N;  p.angle_deg = angle_from_normal_deg;
p.bracket_type = bracket_type;  p.a = a;  p.y = y;  p.SF = SF;
p.inserts_per_bracket = inserts_per_bracket;
if strcmpi(puck_layout, 'shared'), p.inserts_per_puck = inserts_per_bracket; else, p.inserts_per_puck = 1; end
p.puck_layout = puck_layout;
p.load_convention = load_convention;
p.use_friction = use_friction;  p.bolt_preload = bolt_preload;  p.mu = mu;
p.preload_retention = preload_retention;
p.f = f;  p.vf = vf;  p.Ef = Ef;  p.Sigma_fy = Sigma_fy;  p.tau_f_punch = tau_f_punch;  p.c = c;
p.core_lib = core_lib;  p.panel_core_name = panel_core_name;
p.strength_basis = strength_basis;  p.Gc_scale = Gc_scale;
p.splice = splice;  p.splice_allow_basis = splice_allow_basis;  p.splice_knockdown = splice_knockdown;
p.splice_gap_in = splice_gap_in;  p.splice_film_kgm2 = splice_film_kgm2;
p.inset_each_face_in = inset_each_face_in;
p.ecss_variant = ecss_variant;  p.Pss_knockdown = Pss_knockdown;  p.b_min = b_min;
p.resin_wall_min = resin_wall_min;  p.min_ligament = min_ligament;
p.round_to_std = round_to_std;  p.std_puck_R = std_puck_R;  p.bgrid = bgrid;
p.spool_flange_OD = spool_flange_OD;  p.spool_flange_t = spool_flange_t;
p.spool_neck_dia = spool_neck_dia;  p.spool_hole_dia = spool_hole_dia;
p.rho_al_gcc = rho_al_gcc;  p.rho_potting_gcc = rho_potting_gcc;  p.d_hole = d_hole;

r = resin_puck_size(p);
if ~r.ok
    error('%s Loads too high for this panel.', r.msg);
end
L = r.L;  cp = r.cp;

%% 7. RESULTS
fprintf('\n=== DESIGN LOADS (SF = %.2f) ===\n', SF);
if strcmpi(load_mode, 'bracket')
    fprintf('Link force %.0f N (%.0f lb), %.2f deg from normal, bracket type %s, %d spools per bracket\n', ...
            link_force_N, L.F, angle_from_normal_deg, upper(bracket_type), inserts_per_bracket);
    fprintf('Q before friction = %.0f lb (whole bracket, SF applied); load convention: %s\n', L.Q_before_friction, load_convention);
    if use_friction
        fprintf('Friction credit %.0f lb (%d bolts x %.0f lb x mu %.3f x retention %.2f)  [preload and mu UNVERIFIED]\n', ...
                L.max_friction, inserts_per_bracket, bolt_preload, mu, preload_retention);
    end
else
    fprintf('DIRECT load input per spool (before SF): P = %.0f lb, Q = %.0f lb, M = %.0f lb-in, no friction credit\n', ...
            direct_P, direct_Q, direct_M);
end
fprintf('Per spool: P = %.0f lb   Q = %.0f lb   M = %.0f lb-in\n', L.P, L.Q, L.M);
if p.inserts_per_puck > 1
    fprintf('Puck layout: SHARED round puck holding %d spools at +/- %.2f in from its centre.\n', p.inserts_per_puck, a/2);
    fprintf('  Loads on the puck (bracket resultants): P = %.0f lb   Q = %.0f lb   M = %.0f lb-in\n', r.Pp, r.Qp, r.Mp);
else
    fprintf('Puck layout: SEPARATE, one puck per spool (loads as above).\n');
end
fprintf('Panel: f = %.4f in (%d plies x %.3f mm), c = %.3f in   [layup is an UNVERIFIED placeholder; c = 1 in confirmed by the user]\n', f, n_plies, t_ply_mm, c);
fprintf('Panel core: %s (%.1f pcf, cell %.4f in), tau_W %s = %.0f psi, Gc = G_W = %.0f psi\n', ...
        cp.name, cp.rho_pcf, cp.Sc, strength_basis, cp.Twcrit, cp.Gc);
fprintf('  UNVERIFIED: core data from the Hexcel table in CLAUDE.md (not the datasheet of the core bought), foil gauge not populated\n');

fprintf('\n=============================================================\n');
fprintf('=== RESULT: RESIN PUCK RADIUS AND REQUIRED SPLICE BOND ===\n');
fprintf('=============================================================\n');
fprintf('Required radius by failure mode (hole radius in the core; ECSS variant: %s):\n', ecss_variant);
fprintf('  %-46s %6.3f in\n', 'ECSS core shear in panel core', r.R_ecss);
fprintf('  %-46s %6.3f in\n', 'Face-sheet punch-out (placeholder strength)', r.R_punch);
fprintf('  %-46s %6.3f in  (puck radius floor%s)\n', 'Geometry: spool flange + resin wall', r.R_geom, ...
        ternary_str(r.offset > 0, sprintf(', incl. %.2f in spool offset', r.offset), ''));
fprintf('  Governs: %s\n', r.gov);
fprintf('  For comparison, the %s ECSS convention gives %.3f in\n', r.other_variant, r.ecss_other.b_eff_req);
fprintf('\nRESIN PUCK RADIUS TO MOLD: %.3f in (dia %.3f in)%s   [needed %.3f in]\n', r.R_p_std, 2*r.R_p_std, ...
        ternary_str(r.beyond_std, '  (beyond the standard list, rounded up)', ''), r.R_p_req);
fprintf('  Hole radius in the core: %.3f in (puck + %.3f in splice gap, gap is a PLACEHOLDER)\n', r.R_h_std, splice_gap_in);
fprintf('  Resin / splice wall height h = %.3f in (core %.3f in minus 2 x %.3f in inset; inset is a PLACEHOLDER, 0 = resin as tall as the core)\n', r.h, c, inset_each_face_in);
fprintf('  Spool flanges flush with the skins (user). One round puck per bracket holds %d spool(s).\n', p.inserts_per_puck);

fprintf('\nREQUIRED SPLICE BOND STRENGTH (reported, not sized), on the full wall area of the puck:\n');
fprintf('  Axial shear, average, for push-out coupons : %6.0f psi on the puck wall (%.0f psi on the core wall)\n', r.tau_avg_puck, r.tau_avg_core);
fprintf('                                               = P / (2*pi*R*h), all load through the wall, no skin credit\n');
fprintf('  Axial shear, PEAK with moment M            : %6.0f psi on the puck wall (%.0f psi on the core wall)\n', r.tau_pk_puck, r.tau_pk_core);
fprintf('                                               = P/(2*pi*R*h) + M/(pi*R^2*h)  [rigid-puck estimate, ours, not ECSS]\n');
fprintf('  Wall normal stress from in-plane Q         : %6.0f psi on the puck wall (%.0f psi on the core wall)\n', r.sig_q_puck, r.sig_q_core);
fprintf('                                               = Q/(pi*R*h), film in tension on the trailing side [ours, not ECSS]\n');
fprintf('  Allowable bracket (AF 3074 data is on SOLID Al tubes, not honeycomb; foil solidity of %s = %.1f%%):\n', cp.name, 100*r.solidity);
for k = 1:numel(r.allow.vals)
    fprintf('    %-42s %6.0f psi : MS average %6.2f, peak %6.2f\n', r.allow.names{k}, r.allow.vals(k), r.allow.ms_avg(k), r.allow.ms_peak(k));
end
fprintf('  Selected basis (splice_allow_basis): %s = %.0f psi -> MS average %.2f, peak %.2f\n', r.allow_basis, r.tau_allow, r.ms_bond_avg, r.ms_bond_peak);
fprintf('  The datasheet cannot settle the honeycomb allowable: a push-out coupon must beat %.0f psi (peak) on the puck wall.\n', r.tau_pk_puck);

fprintf('\nMargins at the standard size (>0 passes):\n');
fprintf('  %-52s MS = %7.2f   (1 - sum of squares, not a load ratio)\n', 'ECSS core shear interaction in panel core', r.ms_ecss);
fprintf('  %-52s MS = %7.2f   (placeholder strength)\n', 'Face-sheet punch-out', r.ms_punch);
fprintf('  %-52s MS = %7.2f   (%s)\n', 'Splice bond, axial average', r.ms_bond_avg, r.allow_basis);
fprintf('  %-52s MS = %7.2f   (%s)\n', 'Splice bond, axial peak with M', r.ms_bond_peak, r.allow_basis);
if ~isnan(r.ms_spacing)
    fprintf('  %-52s MS = %7.2f   (bolt spacing a = %.2f in vs 2R + ligament = %.2f in)\n', 'Puck-to-puck spacing', r.ms_spacing, a, r.spacing_min);
    if r.ms_spacing < 0
        fprintf('  WARNING: separate pucks (R = %.3f in) do not fit at the bolt spacing a = %.2f in. Use a shared puck, widen the bolt spacing, or reduce load per spool.\n', r.R_h_std, a);
    end
end

fprintf('\nIn-plane capacity Qss (core + skin contributions): at R = %.3f in the core term is %.0f lb and the skin term %.0f lb\n', ...
        r.R_h_std, r.qss_core, r.qss_skin);
fprintf('  (equal at R = %.2f in; core term uses plate shear strength, not crush; sigma_fy is a PLACEHOLDER)\n', r.R_core_skin_equal);
if r.Qp <= 0
    fprintf('  The Qss fit is only valid for R < 0.433 in; it is extrapolated at this size, but Q = 0 here so it does not enter.\n');
elseif r.qss_extrapolated
    fprintf('  NOTE: Q = %.0f lb enters and R is above 0.433 in: the Qss fit (valid below 0.433 in) is EXTRAPOLATED.\n', r.Qp);
end

fprintf('\nMass per puck: %.0f g gross (spool(s) %.1f g + resin %.0f g [%.3f in^3 at %.2f g/cc] + splice film %.1f g [%s, %.2f kg/m^2]), %.0f g net of the %.0f g core removed\n', ...
        1000*r.mass.gross, 1000*r.mass.spool, 1000*r.mass.resin, r.mass.V_resin, rho_potting_gcc, 1000*r.mass.film, splice.name, splice_film_kgm2, ...
        1000*r.mass.net, 1000*r.mass.displaced);
fprintf('  Per bracket (%g puck(s)): %.0f g net\n', r.pucks_per_bracket, 1000*r.mass.net_per_bracket);

%% 7b. LAYOUT COMPARISON
fprintf('\n=== LAYOUT COMPARISON: ONE SHARED ROUND PUCK vs ONE PUCK PER SPOOL ===\n');
for ipp = unique([1 inserts_per_bracket])
    pp = p;  pp.inserts_per_puck = ipp;
    rr = resin_puck_size(pp);
    if ipp == 1, nm = 'separate'; else, nm = 'shared'; end
    if rr.ok
        if ~isnan(rr.ms_spacing)
            sp_txt = sprintf('spacing %s (a = %.2f in vs %.2f in needed)', ternary_str(rr.ms_spacing < 0, 'FAILS', 'ok'), a, rr.spacing_min);
        else
            sp_txt = 'one puck, no spacing check';
        end
        fprintf('  %-8s: puck R %.3f in std (needed %.3f), %g puck(s) per bracket, %.0f g net per bracket, peak bond %.0f psi, %s\n', ...
                nm, rr.R_p_std, rr.R_p_req, rr.pucks_per_bracket, 1000*rr.mass.net_per_bracket, rr.tau_pk_puck, sp_txt);
    else
        fprintf('  %-8s: %s\n', nm, rr.msg);
    end
end
fprintf('  A shared ROUND puck is conservative for ECSS (one big circle through both spools); a lozenge/stadium puck would be lighter but is not modeled.\n');

fprintf('\n=== RESIN AND SPLICE NOTES ===\n');
fprintf('  Resin %s (%s): %.2f g/cc, neat compressive yield %.0f psi (%s)\n', pot.name, pot.source, pot.rho_gcc, pot.comp_yield_psi, pot.comp_note);
fprintf('  Thermal: %s\n', pot.Tg_note);
fprintf('  The puck is fully cured BEFORE splicing, then sees the %.0f F co-cure again with the film. The resin strength is not used in any\n', cure_temp_F);
fprintf('  check here, and its onset-of-storage-modulus Tg (%.0f F after a 302 F post-cure) is below the %.0f F co-cure.\n', pot.Tg_onset_F, cure_temp_F);
fprintf('  Splice film %s (%s, %.0f mil, %.2f kg/m^2):\n', splice.name, splice.source, 1000*splice.thickness_in, splice.areal_kgm2);
fprintf('    cure %d-%d F (starts at %d-%d F, suggested minimum %d F); service %d to %d F; expansion ~%d%% (257 F x 60 min) / ~%d%% (320 F hot-in);\n', ...
        splice.cure_range_F(1), splice.cure_range_F(2), splice.cure_onset_F(1), splice.cure_onset_F(2), splice.cure_min_F, ...
        splice.service_F(1), splice.service_F(2), splice.expansion_A_pct, splice.expansion_B_pct);
fprintf('    free-expanded thickness of a %.0f mil film ~%.0f-%.0f mil (a rough ceiling on the gap it can fill; confined foaming differs).\n', ...
        1000*splice.thickness_in, 1000*splice.thickness_in*(1 + splice.expansion_B_pct/100), 1000*splice.thickness_in*(1 + splice.expansion_A_pct/100));
fprintf('    tube shear on solid Al tubes, 257 F cure: %d psi at %d F, %d psi at %d F, %d psi at %d F, %d psi at %d F.\n', ...
        splice.tube_shear_psi(1), splice.tube_shear_F(1), splice.tube_shear_psi(2), splice.tube_shear_F(2), ...
        splice.tube_shear_psi(3), splice.tube_shear_F(3), splice.tube_shear_psi(4), splice.tube_shear_F(4));
fprintf('  UNVERIFIED: the datasheet is PRELIMINARY and typical only; it has no strength data for a %.0f F cure (expansion falls with hotter cures),\n', cure_temp_F);
fprintf('  and none on honeycomb. The splice gap and resin inset values are placeholders.\n');
fprintf('  NOT CHECKED: spool-to-resin bond and flange bearing, resin shear around the spool, spool neck compression, bolt checks,\n');
fprintf('  puck-to-skin bond (the resin is inset from the skins), thermal mismatch between resin and Al/honeycomb.\n');

%% 8. SENSITIVITY
if run_sensitivity
    fprintf('\n=== SENSITIVITY (one input varied at a time) ===\n');
    fprintf('  columns: puck radius needed | standard radius | peak bond required (puck wall)\n');
    sens = {'friction credit ON/OFF (1/0)',     'use_friction',      [1 0],                    false; ...
            'tau_f_punch (psi)',                'tau_f_punch',       [7000 10500 14000 21000], false; ...
            'splice gap (in)',                  'splice_gap_in',     [0 0.03 0.06 0.10],       false; ...
            'resin inset per face (in)',        'inset_each_face_in', [0 0.03 0.06 0.10],      false; ...
            'Gc scale (1 = G_W, 1/3 = old /3)', 'Gc_scale',          [1/3 1],                  false; ...
            'core strength basis (0=min,1=typ)', 'strength_basis',   [0 1],                    false};
    for k = 1:size(sens, 1)
        fprintf('  %s\n', sens{k,1});
        for v = sens{k,3}
            pp = p;
            switch sens{k,2}
                case 'use_friction',   pp.use_friction = logical(v);
                case 'strength_basis', if v == 1, pp.strength_basis = 'typ'; else, pp.strength_basis = 'min'; end
                otherwise,             pp.(sens{k,2}) = v;
            end
            rr = resin_puck_size(pp);
            if rr.ok
                fprintf('    %8.4g : R needed %.3f in | standard %.3f in | peak bond %.0f psi\n', v, rr.R_p_req, rr.R_p_std, rr.tau_pk_puck);
            else
                fprintf('    %8.4g : %s\n', v, rr.msg);
            end
        end
    end
    fprintf('  Standard-size rounding hides small changes; compare "needed" columns.\n');
end

%% 9. BATCH
if run_batch && exist(hardpoint_csv, 'file')
    hp = read_hardpoint_csv(hardpoint_csv);
    fprintf('\n=== BATCH: %d hardpoints from %s ===\n', numel(hp), hardpoint_csv);
    fprintf('  GEOMETRY of every row except FLCA fore is a PLACEHOLDER (FLCA-F values reused): totals are INDICATIVE ONLY.\n');
    fprintf('  Puck layout: %s. P, Q, M below are the loads on ONE puck (SF applied).\n', puck_layout);
    fprintf('  %-20s %4s %5s %5s %5s | %7s %7s | %8s %8s | %5s | %s\n', 'hardpoint', 'qty', 'P', 'Q', 'M', 'R_need', 'R_std', 'tau_avg', 'tau_peak', 'g/brk', 'governs / flags');
    tot_net = 0;  tot_gross = 0;  tot_pucks = 0;  tot_brk = 0;  std_all = [];  std_cnt = [];  nspace = 0;
    for i = 1:numel(hp)
        pp = p;
        flds = fieldnames(hp);
        for j = 1:numel(flds)
            switch flds{j}
                case {'name', 'qty', 'geom_verified'}, continue
                case 'panel_core',   pp.panel_core_name = hp(i).panel_core;
                case 'use_friction', pp.use_friction = logical(hp(i).use_friction);
                otherwise,           pp.(flds{j}) = hp(i).(flds{j});
            end
        end
        if strcmpi(puck_layout, 'shared'), pp.inserts_per_puck = pp.inserts_per_bracket; else, pp.inserts_per_puck = 1; end
        rr = resin_puck_size(pp);
        flag = '';
        if ~hp(i).geom_verified, flag = [flag ' GEOM-PLACEHOLDER']; end %#ok<AGROW>
        if ~rr.ok
            fprintf('  %-20s %4d  NO SOLUTION: %s%s\n', hp(i).name, hp(i).qty, rr.msg, flag);
            continue
        end
        if rr.ms_spacing < 0, flag = [flag ' SPACING-FAILS']; end %#ok<AGROW>
        if rr.qss_extrapolated, flag = [flag ' Qss-extrapolated']; end %#ok<AGROW>
        fprintf('  %-20s %4d %5.0f %5.0f %5.0f | %7.3f %7.3f | %8.0f %8.0f | %5.0f | %s;%s\n', hp(i).name, hp(i).qty, ...
                rr.Pp, rr.Qp, rr.Mp, rr.R_p_req, rr.R_p_std, rr.tau_avg_puck, rr.tau_pk_puck, 1000*rr.mass.net_per_bracket, rr.gov, flag);
        if hp(i).qty > 0
            tot_net    = tot_net   + hp(i).qty*rr.mass.net_per_bracket;
            tot_gross  = tot_gross + hp(i).qty*rr.mass.gross_per_bracket;
            tot_pucks  = tot_pucks + hp(i).qty*rr.pucks_per_bracket;
            tot_brk    = tot_brk   + hp(i).qty;
            [std_all, std_cnt] = tally(std_all, std_cnt, rr.R_p_std, hp(i).qty*rr.pucks_per_bracket);
            if rr.ms_spacing < 0, nspace = nspace + hp(i).qty; end
        end
    end
    fprintf('\n  Standard puck radii (in : count of pucks):');
    for k = 1:numel(std_all), fprintf('  %.3f : %d', std_all(k), std_cnt(k)); end
    fprintf('\n  Car total (%d brackets, %d pucks): %.2f kg net of core removed, %.2f kg gross (spool + resin + film)\n', tot_brk, tot_pucks, tot_net, tot_gross);
    fprintf('  Brackets whose pucks do not fit at the bolt spacing used: %d of %d\n', nspace, tot_brk);
elseif run_batch
    fprintf('\n(batch skipped: %s not found in the current folder)\n', hardpoint_csv);
end

%% 10. PLOT
if make_plots
    figure;
    plot(r.ecss.b_eff, r.ecss.MS, 'r', 'LineWidth', 2); hold on;
    plot(r.ecss_other.b_eff, r.ecss_other.MS, 'b--', 'LineWidth', 1.5);
    plot(r.R_ecss, 0, 'ro', 'MarkerFaceColor', 'r');
    yline(0, 'k:');
    xlim([0 3]); ylim([-1 1]);
    xlabel('Hole radius (in)'); ylabel('Margin of safety (ECSS core shear, panel core)');
    legend(sprintf('%s (used)', ecss_variant), sprintf('%s (comparison)', r.other_variant), 'Location', 'southeast');
    title(sprintf('Link %.0f N, SF %.1f, panel core %s', link_force_N, SF, panel_core_name));
    grid on;
end
