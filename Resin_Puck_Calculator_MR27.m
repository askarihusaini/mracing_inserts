%% MR27 RESIN PUCK INSERT CALCULATOR
% Sizes a cast resin puck (Pro-Set LAM-151-HT around an Al NAS03 spool, fully cured in a jig) that is
% spliced into the 6.1 pcf honeycomb with 3M AF 3074 core splice film and co-cured at 350 F.
% Outputs the puck radius, the failure mode that governs, and the bond strength the splice must provide.
%
% Based on G7_Insert_Calculator_MR27_20261008.m (the G7 plug calculator), same layout and sections.
% Equations based on Insert_calculator_2025_v2_1.mlx.
% ECSS-E-HB-32-22A core-shear equations are unedited.
%
% CHANGES FROM THE G7 PLUG CALCULATOR
%   * Plug material (G7/G10/G11) -> resin puck material (LAM-151-HT) with an Al spool inside.
%   * Gc = G_W (the old G_W/3 is dropped). Link force is Rev15 (8140 N).
%   * Both bolts of the bracket can share ONE puck, so the puck carries the bracket loads. For two
%     bolts the puck is a figure-8 (two overlapping circles) or a stadium (slot). ECSS only covers one
%     round insert, so the two-bolt outline is sized with an equal-PERIMETER equivalent round puck.
%     That is our approximation, not ECSS.
%   * Plug-to-core bond -> splice bond (same idea: reported as the required strength).
%   * Plug-only checks (washer crush, bolt bearing in plug, washer punch-through) are replaced by a
%     spool neck compression check. The bolt now bears on the Al spool, not the puck.
%   * The potted reference insert and the potted ECSS curve are removed (the puck is the potted insert now).

clear; close all; clc;

%% 1. LOADS
% Default is worst load case from MR27_Suspension_Loads_Rev15
link_force_N          = 8140;    % max link force (N)
angle_from_normal_deg = 10.45;   % link angle from panel normal (deg) based on MR26 FLCA-F geometry
bracket_type          = 'B';     % 'A' or 'B' bracket style
a                     = 1.52;    % distance between bolts (in)
y                     = 0.4185;  % spherical to middle of bracket base (in)

SF = 2;                          % safety factor applied to loads

% Load mode: 'bracket' uses the link force and bracket geometry above (suspension arms).
% 'direct' skips the bracket and applies loads straight to the puck (non-suspension parts).
load_mode    = 'bracket';        % 'bracket' or 'direct'
direct_P_lb  = 1000;             % 'direct' mode: normal (pull-out) load on ONE puck, before SF
direct_Q_lb  = 0;                % in-plane shear on the puck, before SF
direct_M_lbin = 0;               % moment on the puck, before SF

% Friction credit (same assumption as old calc). With these numbers friction
% (850 lb per bracket) cancels all shear for every control arm at SF 2-2.5.
% Set use_friction = false for a conservative shear check.
use_friction = true;
bolt_preload = 2125.8;           % lb per bolt, 75% of proof load (old calc value)
mu           = 0.2;              % Al bracket on carbon (old calc value; sheet uses 0.175)
n_bolts      = 2;                % bolts per bracket

puck_bolts = 2;                  % bolts that share one puck: 2 = both bolts of the bracket, 1 = one puck per bolt
puck_shape = 'figure8';          % shape of a 2-bolt puck: 'figure8' (two overlapping circles) or 'stadium' (slot)

%% 2. SANDWICH PANEL
% This is where ply thickness and core thickness go. old calc hard-coded these
% in its CORE PROPERTIES / FACE SHEET PROPERTIES blocks (c = 0.75,
% f = 0.055); here f is built from our ply count and ply thickness.

% Face sheet (one skin)
n_plies   = 3;                   % plies per face sheet  PLACEHOLDER
t_ply_mm  = 0.18;                % cured ply thickness (mm)  PLACEHOLDER
f         = n_plies * t_ply_mm / 25.4;   % face sheet thickness (in)
vf        = 0.3;                 % Poisson's ratio = sqrt(vxy*vyx)
Ef        = 4.33e6;              % Young's modulus (psi) = sqrt(Ex*Ey) (SES value)
Sigma_fy  = 14000;               % interlaminar shear strength of skin (psi) - old calc value
tau_f_punch = 14000;             % skin through-thickness shear (punch) strength (psi) PLACEHOLDER

% Core (global 6.1 pcf, Hexcel HexWeb CR-III 5052 1/8-6.1, W direction)
c         = 1;                   % core height (in)
Gc        = 41000;               % core effective shear modulus (psi) = G_W. Old calc used G_W/3 = 13667; dropped.
Twcrit    = 272;                 % core shear strength (psi), minimum value (old calc value)

%% 3. RESIN PUCK MATERIAL  <-- EDIT
% Values are from the datasheet of the neat resin, NOT measured on our part:
%   rho_gcc: density
%   Fcu_flat: neat compressive yield (ASTM D695, 302 F post-cure)
%   T_max_C: glass transition (DMA onset) / max service temp (must clear the cure)
resin_material = 'LAM-151-HT';

switch resin_material
    case 'LAM-151-HT'   % Pro-Set LAM-151-HT / LAM-251-HT, Rev 6 Mar 2025, UNFILLED (no glass beads)
        mat.name = 'LAM-151-HT'; mat.rho_gcc = 1.13;
        mat.Fcu_flat = 16300;    mat.T_max_C = 164;     % Tg onset 328 F. No datasheet data at a 350 F cure.
        mat.verified = false;
end

cure_temp_F = 350;               % monocoque cure temperature (F)  <-- EDIT if you lower it

%% 4. SPLICE BOND (3M AF 3074)
% Shear the splice film line between the puck wall and the cut honeycomb can
% carry, averaged over the full puck wall area (perimeter * wall height). Only the foil
% edges touch the film, so this is NOT the adhesive's datasheet strength. The AF 3074
% datasheet (preliminary, June 2025) only gives 1883 psi tube shear on SOLID Al tubes, 257 F cure.
% Ideally we should empirically test what this actually is.
% Default = core shear strength (Twcrit), the same assumption as the G7 calculator: the core
% fails before the splice. Replace with push-out coupon data
% (tau = load / (perimeter*h)) when we have it.
tau_bond_allow = Twcrit;         % psi
bond_is_measured = false;        % set true once tau_bond_allow comes from your tests
bond_knockdown = 1.0;            % extra knockdown on the bond (1 = none)
inset_each_face = 0.0;           % resin inset below each skin (in), so the bonded wall is c - 2*inset  PLACEHOLDER

%% 5. HARDWARE AND SIZING RULES
resin_wall_min = 0.125;          % min resin wall outside the spool flange (in)  PLACEHOLDER
b_min    = 0.25;                 % floor on radius (old calc floored at 0.25")
b_step   = 0;                    % round puck radius up to this step (in); 0 = no rounding
Pss_knockdown = 0.89;            % ECSS min-vs-typical knockdown (old calc value)
make_plots = true;

% Spool: NAS03 Al spool, "Insert lengths 26" tab of the MR26 sheet.
% Spool length is taken as the full panel thickness (2*f + c).
spool_flange_OD  = 0.500;        % in
spool_flange_t   = 0.080;        % in, each flange
spool_neck_dia   = 0.291;        % in
spool_hole_dia   = 0.191;        % in, bolt clearance through the spool
rho_al_gcc       = 2.70;         % Al 6061 (g/cc)
spool_neck_yield = 35000;        % psi, 6061-T6 minimum yield, assumed  PLACEHOLDER (confirm spool alloy/temper)

%% 6. DESIGN LOADS PER INSERT
switch lower(load_mode)
    case 'bracket'
        F   = link_force_N * 0.224809;               % N -> lb
        ang = angle_from_normal_deg * pi/180;
        Fn  = F*cos(ang);                            % normal to panel, whole bracket
        Fs  = F*sin(ang);                            % in-plane, whole bracket

        switch upper(bracket_type)
            case 'B'   % both bolts share the normal load; moment carried at base
                P_ins = Fn/2;
                M_ins = Fs*y;
            case 'A'   % moment resolved into a bolt-load couple (sheet FBD)
                P_ins = Fn/2 + Fs*y/a;               % worst (outside) bolt
                M_ins = 0;
            otherwise
                error('bracket_type must be ''A'' or ''B''');
        end

        max_friction = n_bolts*bolt_preload*mu*use_friction;
        P = SF*P_ins;                                % design normal load per insert (lb)
        Q = max(SF*Fs - max_friction, 0);            % design shear (lb), old calc convention
        M = SF*M_ins;                                % design moment (lb-in)

        % Loads on the PUCK. If both bolts share it, the puck carries the bracket resultants (the bolt
        % couple of a type A bracket is internal to the rigid puck). If each bolt has its own puck, each
        % puck carries the per-insert loads above, as in the G7 calculator.
        if puck_bolts == n_bolts
            P_puck = SF*Fn;   M_puck = SF*Fs*y;
        elseif puck_bolts == 1
            P_puck = P;       M_puck = M;
        else
            error('puck_bolts must be 1 or equal to n_bolts.');
        end
        Q_puck = Q;
    case 'direct'
        % Loads are given directly on one puck; no bracket and no friction credit.
        if puck_bolts > 2, error('puck_bolts must be 1 or 2.'); end
        F = NaN;  max_friction = 0;
        P_puck = SF*direct_P_lb;  Q_puck = SF*direct_Q_lb;  M_puck = SF*direct_M_lbin;
        if P_puck <= 0, error('Direct mode needs direct_P_lb > 0.'); end
        P = P_puck/puck_bolts;  Q = Q_puck;  M = M_puck;     % per-bolt P is used by the spool neck check
    otherwise
        error('load_mode must be ''bracket'' or ''direct''');
end

%% 7. ECSS CORE-SHEAR CHECK  (same equations as old calc)
beta   = c/f;                                                 % [C.2-9]
alpha  = 1/f * sqrt(Gc/Ef*12*(1-vf^2)*(1+beta/2));            % [C.2-10]
C_star = beta/(beta+1);                                       % [C.2-14]
Kmax   = @(b) b./(b./(1-exp(-.931714.*(alpha.*b).^.262866))) ...
            .*(1-sqrt((b./(1-exp(-.931714.*(alpha.*b).^.262866)))./b) ...
            .*exp(alpha.*(b-b./(1-exp(-.931714.*(alpha.*b).^.262866)))));  % [C.2-16],[C.2-6]
Pcrit  = @(b) 2*pi.*b.*c.*Twcrit./(C_star.*Kmax(b));          % [C.2-17]
Qss    = @(b) 8*b.^2*Twcrit + 2*f.*b.*Sigma_fy;               % [14.2-1]

b = linspace(0.15, 4, 20000);                                 % candidate radius of an equivalent ROUND puck (in)

% Rigid puck: radius b everywhere (the resin does not fill the cells), loads on the puck
MS_plug = 1 - ((Q_puck./Qss(b)).^2 + (P_puck./(Pss_knockdown*Pcrit(b))).^2 + (M_puck./(Pcrit(b).*b)).^2);

i1 = find(MS_plug >= 0, 1);
if isempty(i1)
    error('No radius under 4" satisfies the ECSS check - loads too high for this panel.');
end
b_ecss = b(i1);          % radius of the equivalent round puck (in)

%% 8. PUCK SIZING CHECKS
% The puck is SIZED like old calc sizes potting (ECSS core shear), plus geometric limits and
% face-sheet punch-out. The splice bond is NOT a sizing check (old calc has none); it is reported
% below as the bond strength the design REQUIRES, i.e. the target your push-out coupons have to beat.

% (d) Face-sheet punch-out around the puck perimeter (equivalent round radius)
b_punch = P_puck/(2*pi*f*tau_f_punch);
% (e) Spool flange plus a minimum resin wall (per lobe)
b_edge  = spool_flange_OD/2 + resin_wall_min;

% Two-bolt outline: equal-PERIMETER conversion from the equivalent round radius to the lobe radius.
% (our approximation, NOT ECSS; the figure-8 also ignores the stress concentration at its two cusps)
if puck_bolts == 2 && strcmpi(puck_shape, 'stadium')
    % Stadium: end radius R at each bolt, straight sides a long. Perimeter 2a + 2*pi*R.
    per_f    = @(R) 2*a + 2*pi*R;
    area_f   = @(R) pi*R.^2 + 2*R*a;
    lobe_for = @(Req) max(Req - a/pi, 0);
elseif puck_bolts == 2
    % Figure-8: two circles of radius R, centres a apart (union of the two).
    th_f     = @(R) acos(min(a./(2*R), 1));                   % half-angle of the arc lost inside the overlap
    per_f    = @(R) 4*R.*(pi - th_f(R));
    area_f   = @(R) 2*pi*R.^2 - (2*R.^2.*th_f(R) - (a/2)*sqrt(max(4*R.^2 - a^2, 0)));
    Rg       = linspace(0.01, 8, 80000);
    lobe_for = @(Req) Rg(find(per_f(Rg) >= 2*pi*Req, 1));     % smallest lobe whose outline has perimeter >= 2*pi*Req
else
    per_f    = @(R) 2*pi*R;                                   % one bolt: a round puck
    area_f   = @(R) pi*R.^2;
    lobe_for = @(Req) Req;
end

req_names = {'ECSS core shear (old calc eqns)', 'Face-sheet punch-out', ...
             'Spool flange + resin wall', 'Minimum radius floor'};
req_vals  = [lobe_for(b_ecss), lobe_for(b_punch), b_edge, b_min];
[b_req, igov] = max(req_vals);
if b_step > 0
    b_design = ceil(b_req/b_step - 1e-9)*b_step;
else
    b_design = b_req;   % exact radius at the governing limit
end
b_round = per_f(b_design)/(2*pi);     % equivalent round radius of the final outline (= b_design for one round puck)

% (c) Splice bond requirement at the design size.
% Conservative: all of P through the puck wall, no credit for the skins.
h            = c - 2*inset_each_face;                               % bonded wall height (in)
perim        = per_f(b_design);                                     % bonded perimeter (in)
tau_bond_req = P_puck/(perim*h);                                    % psi, average
tau_bond_pk  = tau_bond_req + M_puck/(pi*b_round^2*h);              % psi, peak when the moment tilts the puck (ours, not ECSS)
sig_bond_Q   = Q_puck/(pi*b_round*h);                               % psi, peak normal stress on the wall from Q
MS_bond      = tau_bond_allow*bond_knockdown/tau_bond_req - 1;

% Spool neck compression (radius-independent). Push-in direction: bolt preload clamps the neck and the
% pushed-in link load adds to it. The neck is checked ALONE: any compression the resin shares is ignored.
A_neck     = pi/4*(spool_neck_dia^2 - spool_hole_dia^2);            % in^2
F_neck     = bolt_preload + P;                                      % lb per spool (P = per-insert load)
sig_neck   = F_neck/A_neck;                                         % psi
MS_neck    = spool_neck_yield/sig_neck - 1;
OD_neck_req = sqrt(4*(F_neck/spool_neck_yield)/pi + spool_hole_dia^2);   % neck OD for MS = 0 at this bore (in)

%% 9. RESULTS
in3_to_cc = 16.387064;
% Puck mass: Al spool(s) + resin filling the puck outline (height c) except where the spool and its bolt hole sit.
L_spool    = 2*f + c;                                                % in
V_flanges  = 2 * pi/4*(spool_flange_OD^2 - spool_hole_dia^2)*spool_flange_t;
V_neck     = pi/4*(spool_neck_dia^2 - spool_hole_dia^2)*(L_spool - 2*spool_flange_t);
V_spool    = V_flanges + V_neck;                                     % solid Al (in^3)
V_spool_in_core = V_spool - pi/4*(spool_flange_OD^2 - spool_hole_dia^2)*2*f;
V_hole_in_core  = pi/4*spool_hole_dia^2*c;
V_resin    = area_f(b_design)*c - puck_bolts*(V_spool_in_core + V_hole_in_core);   % in^3
m_spool    = puck_bolts*rho_al_gcc*in3_to_cc/1000*V_spool;           % kg
m_resin    = mat.rho_gcc*in3_to_cc/1000*V_resin;                     % kg
m_puck     = m_spool + m_resin;                                      % kg

fprintf('\n=== DESIGN LOADS (SF = %.2f) ===\n', SF);
if strcmpi(load_mode, 'bracket')
    fprintf('Link force %.0f N (%.0f lb), %.2f deg from normal, bracket type %s\n', ...
            link_force_N, F, angle_from_normal_deg, upper(bracket_type));
else
    fprintf('Direct load mode (no bracket, no friction credit)\n');
end
fprintf('Per insert: P = %.0f lb   Q = %.0f lb   M = %.0f lb-in   (friction credit %.0f lb)\n', P, Q, M, max_friction);
fprintf('On the puck (%d bolt(s)): P = %.0f lb   Q = %.0f lb   M = %.0f lb-in\n', puck_bolts, P_puck, Q_puck, M_puck);
fprintf('Panel: f = %.4f in (%d plies x %.3f mm), c = %.3f in\n', f, n_plies, t_ply_mm, c);

fprintf('\n=== %s PUCK: REQUIRED RADIUS BY FAILURE MODE ===\n', mat.name);
for k = 1:numel(req_vals)
    tag = '';  if k == igov, tag = '  <-- governs'; end
    fprintf('  %-32s %6.3f in%s\n', req_names{k}, req_vals(k), tag);
end
if puck_bolts == 2
    fprintf('  (radius of each lobe; equivalent round puck: ECSS %.3f in, punch-out %.3f in)\n', b_ecss, b_punch);
    if strcmpi(puck_shape, 'stadium')
        fprintf('Puck to mold: stadium, end radius %.4f in, bolt centres %.2f in apart, %.2f x %.2f in, approx. mass %.1f g\n', ...
                b_design, a, a + 2*b_design, 2*b_design, 1000*m_puck);
    else
        fprintf('Puck to mold: figure-8, lobe radius %.4f in, bolt centres %.2f in apart, %.2f x %.2f in, approx. mass %.1f g\n', ...
                b_design, a, a + 2*b_design, 2*b_design, 1000*m_puck);
    end
else
    fprintf('Puck radius to mold: %.4f in (dia %.4f in), approx. mass %.1f g\n', b_design, 2*b_design, 1000*m_puck);
end

fprintf('\n=== SPLICE BOND REQUIREMENT (target for push-out coupons) ===\n');
fprintf('  Bond must carry >= %.0f psi  (= P / (perimeter*h), all load through the wall)\n', tau_bond_req);
fprintf('  Peak with the moment: %.0f psi  (adds M / (pi*Req^2*h))\n', tau_bond_pk);
if Q_puck > 0
    fprintf('  Normal stress on the wall from Q: %.0f psi\n', sig_bond_Q);
end
if bond_is_measured
    src = 'measured';
else
    src = 'core shear strength, not measured';
end
fprintf('  Current allowable %.0f psi (%s) -> MS = %.2f\n', tau_bond_allow, src, MS_bond);
fprintf('  For a coupon of perimeter L and wall height h: pass if failure load > %.0f*L*h lb\n', tau_bond_req);

fprintf('\n=== OTHER CHECKS (margin of safety, >0 passes) ===\n');
fprintf('  Spool neck compression       MS = %6.2f  (%.0f psi vs %.0f psi yield; preload %.0f + push-in %.0f lb on %.4f in^2)\n', ...
        MS_neck, sig_neck, spool_neck_yield, bolt_preload, P, A_neck);
if MS_neck < 0
    fprintf('    Neck alone FAILS. Neck OD for MS = 0 at the %.3f in bore: %.3f in (now %.3f in, flange OD %.3f in).\n', ...
            spool_hole_dia, OD_neck_req, spool_neck_dia, spool_flange_OD);
    fprintf('    The resin around the neck may share the compression; this check ignores that.\n');
end
T_cure_C = (cure_temp_F-32)*5/9;
if mat.T_max_C < T_cure_C
    fprintf('  WARNING: %s max temp %.0f C is below the %.0f C (%.0f F) cure.\n', ...
            mat.name, mat.T_max_C, T_cure_C, cure_temp_F);
end
if ~mat.verified
    fprintf('\n  NOTE: %s material properties are still datasheet values for the neat resin.\n', mat.name);
end
if ~bond_is_measured
    fprintf('  NOTE: bond allowable = core shear strength (%.0f psi), not measured.\n', tau_bond_allow);
end
if puck_bolts == 2
    fprintf('  NOTE: two-bolt puck sizing is an equal-perimeter approximation (ours, not ECSS).\n');
end
if Q_puck == 0 && use_friction && strcmpi(load_mode, 'bracket')
    fprintf('  NOTE: friction cancels all of Q (bolt preload and mu are placeholders).\n');
end

if make_plots
    figure;
    plot(b, MS_plug, 'r', 'LineWidth', 2); hold on;
    plot(b_ecss, 0, 'ro', 'MarkerFaceColor', 'r');
    yline(0, 'k:');
    xlim([0 4]); ylim([-1 1]);
    xlabel('Radius of equivalent round puck (in)'); ylabel('Margin of safety (ECSS core shear)');
    legend([mat.name ' puck'], 'Location', 'southeast');
    title(sprintf('Link %.0f N, SF %.1f', link_force_N, SF));
    grid on;
end
