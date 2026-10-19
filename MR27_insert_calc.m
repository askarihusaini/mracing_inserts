%% MR27 RIGID PLUG INSERT CALCULATOR
% Sizes a machined laminate plug co-cured into the honeycomb as well as a
% potted spool potting radius for comparison
%
% Equatoins basesd on Insert_calculator_2025_v2_1.mlx.
% ECSS-E-HB-32-22A core-shear equations are unedited.

clear; close all; clc;

%% 1. LOADS
% Default is worst load case from ME27_Suspension_Loads_Rev14
link_force_N          = 8150;    % max link force (N)
angle_from_normal_deg = 10.45;   % link angle from panel normal (deg) based on MR26 FLCA-F geometry
bracket_type          = 'A';     % 'A' or 'B' bracket style
a                     = 1.52;    % distance between bolts (in)
y                     = 0.4185;  % spherical to middle of bracket base (in)

SF = 2;                          % safety factor applied to loads

% Friction credit (same assumption as old calc). With these numbers friction
% (850 lb per bracket) cancels all shear for every control arm at SF 2-2.5.
% Set use_friction = false for a conservative shear check.
use_friction = true;
bolt_preload = 2125.8;           % lb per bolt, 75% of proof load (old calc value)
mu           = 0.2;              % Al bracket on carbon (old calc value; sheet uses 0.175)
n_bolts      = 2;                % bolts per bracket

%% 2. SANDWICH PANEL
% This is where ply thickness and core thickness go. old calc hard-coded these
% in its CORE PROPERTIES / FACE SHEET PROPERTIES blocks (c = 0.75,
% f = 0.055); here f is built from our ply count and ply thickness.

% Face sheet (one skin)
n_plies   = 3;                   % plies per face sheet
t_ply_mm  = .18;                 % cured ply thickness (mm)
f         = n_plies * t_ply_mm / 25.4;   % face sheet thickness (in)
vf        = 0.3;                 % Poisson's ratio = sqrt(vxy*vyx)
Ef        = 4.33e6;              % Young's modulus (psi) = sqrt(Ex*Ey) (SES value)
Sigma_fy  = 14000;               % interlaminar shear strength of skin (psi) - old calc value
tau_f_punch = 14000;             % skin through-thickness shear (punch) strength (psi) PLACEHOLDER

% Core
c         = 1;                   % core height (in)
Sc        = 0.125;               % core cell size (in)
Gc        = 22000;               % core effective shear modulus (psi)
Twcrit    = 90;                  % core shear strength (psi), minimum value (old calc value)

%% 3. PLUG MATERIAL
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

%% 4. PLUG-TO-CORE BOND
% Shear the bond line between the plug wall and the cut honeycomb can
% carry, averaged over the full plug wall area (2*pi*b*c). Only the foil
% edges touch the plug, so this is NOT the adhesive's datasheet lap shear.
% Ideally we should empirically test what this actually is
% Default = core shear strength (Twcrit), the same strength
% value old calc uses: old calc has no bond term and assumes the core fails
% before the potting-to-core interface. Replace with push-out coupon data
% (tau = load / (2*pi*b*c)) when we have it if we wanna.
tau_bond_allow = Twcrit;         % psi
bond_is_measured = false;        % set true once tau_bond_allow comes from your tests
bond_knockdown = 1.0;            % extra knockdown on the bond (1 = none)

%% 5. HARDWARE AND SIZING RULES
d_bolt   = 0.190;                % bolt diameter (in), 10-32 / NAS03
d_hole   = 0.191;                % clearance hole in plug (in)
d_washer = 0.438;                % washer / nut bearing OD on the plug side (in)
eD_min   = 2.0;                  % min edge distance ratio (plug radius / hole dia)
b_min    = 0.25;                 % floor on radius (old calc floored at 0.25")
b_step   = 0;                    % round plug radius up to this step (in); 0 = no rounding
Pss_knockdown = 0.89;            % ECSS min-vs-typical knockdown (old calc value)
make_plots = true;

% Potted reference insert (for the mass comparison)
% Spool geometry: NAS03 Al spool, "Insert lengths 26" tab of the MR26 sheet.
% Spool length is taken as the full panel thickness (2*f + c).
spool_flange_OD  = 0.500;        % in
spool_flange_t   = 0.080;        % in, each flange
spool_neck_dia   = 0.291;        % in
spool_hole_dia   = 0.191;        % in, bolt clearance through the spool
rho_al_gcc       = 2.70;         % Al 6061 (g/cc)
% Potting: INF-114 + glass beads. MR26 sheet: 0.01868 kg/in^3 neat epoxy,
% x0.6 for glass beads = 0.01121 kg/in^3 (0.68 g/cc).
rho_potting_gcc  = 0.01121*1000/16.387064;   % g/cc

%% 6. DESIGN LOADS PER INSERT
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

%% 7. ECSS CORE-SHEAR CHECK  (same equations as old calc)
beta   = c/f;                                                 % [C.2-9]
alpha  = 1/f * sqrt(Gc/Ef*12*(1-vf^2)*(1+beta/2));            % [C.2-10]
C_star = beta/(beta+1);                                       % [C.2-14]
Kmax   = @(b) b./(b./(1-exp(-.931714.*(alpha.*b).^.262866))) ...
            .*(1-sqrt((b./(1-exp(-.931714.*(alpha.*b).^.262866)))./b) ...
            .*exp(alpha.*(b-b./(1-exp(-.931714.*(alpha.*b).^.262866)))));  % [C.2-16],[C.2-6]
Pcrit  = @(b) 2*pi.*b.*c.*Twcrit./(C_star.*Kmax(b));          % [C.2-17]
Qss    = @(b) 8*b.^2*Twcrit + 2*f.*b.*Sigma_fy;               % [14.2-1]

b = linspace(0.15, 4, 20000);                                 % candidate radius (in)

% (a) Rigid plug: radius b everywhere
MS_plug = 1 - ((Q./Qss(b)).^2 + (P./(Pss_knockdown*Pcrit(b))).^2 + (M./(Pcrit(b).*b)).^2);

% (b) Potted reference, exactly as old calc: bp = bi + 0.35*Sc, Mss uses bi
bp = b + 0.35*Sc;
MS_pot = 1 - ((Q./Qss(bp)).^2 + (P./(Pss_knockdown*Pcrit(bp))).^2 + (M./(Pcrit(bp).*b)).^2);

i1 = find(MS_plug >= 0, 1);   i2 = find(MS_pot >= 0, 1);
if isempty(i1) || isempty(i2)
    error('No radius under 4" satisfies the ECSS check - loads too high for this panel.');
end
b_ecss    = b(i1);      % plug radius from ECSS core shear
bp_ecss   = bp(i2);     % potting radius from ECSS core shear (= old calc result)

%% 8. NEW RIGID-PLUG CHECKS
% The plug is SIZED like old calc sizes potting (ECSS core shear), plus two
% geometric limits. The plug-to-core bond is NOT a sizing check (old calc has
% none); it is reported below as the bond strength the design REQUIRES,
% i.e. the target your push-out coupons have to beat.
% (d) Face-sheet punch-out around the plug perimeter
b_punch = P/(2*pi*f*tau_f_punch);
% (e) Edge distance
b_edge  = eD_min*d_hole;

req_names = {'ECSS core shear (old calc eqns)', 'Face-sheet punch-out', ...
             'Edge distance', 'Minimum radius floor'};
req_vals  = [b_ecss, b_punch, b_edge, b_min];
[b_req, igov] = max(req_vals);

% Potted reference: same breakdown. Face-sheet punch-out applies here too
% (the skin is bonded to the potting out to bp and shears at that edge),
% but the old calc never checked it. Edge distance doesn't apply: the
% bolt hole is in the Al spool, not the potting.
pot_names = {'ECSS core shear (old calc eqns)', 'Face-sheet punch-out (not in old calc)', ...
             'Minimum radius floor'};
pot_vals  = [bp_ecss, b_punch, b_min];
[bp_potted, igov_pot] = max(pot_vals);
if b_step > 0
    b_design = ceil(b_req/b_step - 1e-9)*b_step;
else
    b_design = b_req;   % first grid radius with MS >= 0 (grid step ~0.0002 in)
end

% (c) Plug-to-core bond requirement at the design radius.
% Conservative: all of P through the plug wall, no credit for the skins.
tau_bond_req = P/(2*pi*b_design*c);                                 % psi
MS_bond      = tau_bond_allow*bond_knockdown/tau_bond_req - 1;

% Radius-independent checks (margins at the design radius)
A_washer   = pi/4*(d_washer^2 - d_hole^2);
MS_washer  = mat.Fcu_flat/(max(bolt_preload, P)/A_washer) - 1;   % flatwise crush under washer
Q_bearing  = SF*Fs;                                              % ignores friction: conservative
MS_bearing = mat.Fbru/(Q_bearing/(d_bolt*c)) - 1;                % bolt bearing, plug only
MS_punchthru = (pi*d_washer*c*mat.Fsu_perp)/P - 1;               % washer punching through plug

%% 9. RESULTS
in3_to_cc = 16.387064;
m_plug   = mat.rho_gcc*in3_to_cc/1000 * pi*(b_design^2 - (d_hole/2)^2)*c;     % kg
% Potted insert: Al spool + potting filling the cleared core around it.
L_spool    = 2*f + c;                                                % in
V_flanges  = 2 * pi/4*(spool_flange_OD^2 - spool_hole_dia^2)*spool_flange_t;
V_neck     = pi/4*(spool_neck_dia^2 - spool_hole_dia^2)*(L_spool - 2*spool_flange_t);
V_spool    = V_flanges + V_neck;                                     % solid Al (in^3)
% Potting fills the core cylinder (radius bp, height c) except where the
% spool and its bolt hole sit. Portion of spool + hole inside the core:
V_spool_in_core = V_spool - pi/4*(spool_flange_OD^2 - spool_hole_dia^2)*2*f;
V_hole_in_core  = pi/4*spool_hole_dia^2*c;
V_potting  = pi*bp_potted^2*c - V_spool_in_core - V_hole_in_core;    % in^3
m_spool    = rho_al_gcc*in3_to_cc/1000*V_spool;                      % kg
m_potting  = rho_potting_gcc*in3_to_cc/1000*V_potting;               % kg
m_potted   = m_spool + m_potting;                                    % kg

fprintf('\n=== DESIGN LOADS PER INSERT (SF = %.2f) ===\n', SF);
fprintf('Link force %.0f N (%.0f lb), %.2f deg from normal, bracket type %s\n', ...
        link_force_N, F, angle_from_normal_deg, upper(bracket_type));
fprintf('P = %.0f lb   Q = %.0f lb   M = %.0f lb-in   (friction credit %.0f lb)\n', P, Q, M, max_friction);
fprintf('Panel: f = %.4f in (%d plies x %.3f mm), c = %.3f in\n', f, n_plies, t_ply_mm, c);

fprintf('\n=== POTTED REFERENCE INSERT (old calc method) ===\n');
fprintf('Required potting radius by failure mode:\n');
for k = 1:numel(pot_vals)
    tag = '';  if k == igov_pot, tag = '  <-- governs'; end
    fprintf('  %-40s %6.3f in%s\n', pot_names{k}, pot_vals(k), tag);
end
fprintf('Real potting radius: %.3f in  (old calc alone would give %.3f in)\n', bp_potted, max(bp_ecss, b_min));
fprintf('Mass: %.1f g total = %.1f g Al spool (%.4f in^3, %.3f in long) + %.1f g potting (%.3f in^3)\n', ...
        1000*m_potted, 1000*m_spool, V_spool, L_spool, 1000*m_potting, V_potting);

fprintf('\n=== %s PLUG: REQUIRED RADIUS BY FAILURE MODE ===\n', mat.name);
for k = 1:numel(req_vals)
    tag = '';  if k == igov, tag = '  <-- governs'; end
    fprintf('  %-40s %6.3f in%s\n', req_names{k}, req_vals(k), tag);
end
fprintf('Plug radius to machine: %.4f in (dia %.4f in), approx. mass %.1f g\n', ...
        b_design, 2*b_design, 1000*m_plug);

fprintf('\n=== PLUG-TO-CORE BOND REQUIREMENT (target for push-out coupons) ===\n');
fprintf('  Bond must carry >= %.0f psi  (= P / (2*pi*b*c), all load through the wall)\n', tau_bond_req);
if bond_is_measured
    src = 'measured';
else
    src = 'core shear strength, not measured';
end
fprintf('  Current allowable %.0f psi (%s) -> MS = %.2f\n', tau_bond_allow, src, MS_bond);
fprintf('  For a coupon of radius r and core height h: pass if failure load > %.0f*2*pi*r*h lb\n', tau_bond_req);

fprintf('\n=== OTHER %s CHECKS (margin of safety, >0 passes) ===\n', mat.name);
fprintf('  Washer crush (flatwise)      MS = %6.2f\n', MS_washer);
fprintf('  Bolt bearing in plug         MS = %6.2f  (no friction, plug alone)\n', MS_bearing);
fprintf('  Washer punch-through plug    MS = %6.2f\n', MS_punchthru);
T_cure_C = (cure_temp_F-32)*5/9;
if mat.T_max_C < T_cure_C
    fprintf('  WARNING: %s max temp %.0f C is below the %.0f C (%.0f F) cure.\n', ...
            mat.name, mat.T_max_C, T_cure_C, cure_temp_F);
end
if ~mat.verified
    fprintf('\n  NOTE: %s material properties are still PLACEHOLDERS.\n', mat.name);
end
if ~bond_is_measured
    fprintf('  NOTE: bond allowable = core shear strength (%.0f psi), not measured.\n', tau_bond_allow);
end

if make_plots
    figure;
    plot(b, MS_plug, 'r', 'LineWidth', 2); hold on;
    plot(bp, MS_pot, 'b--', 'LineWidth', 1.5);
    plot(b_ecss, 0, 'ro', 'MarkerFaceColor', 'r');
    plot(bp_ecss, 0, 'bo', 'MarkerFaceColor', 'b');
    yline(0, 'k:');
    xlim([0 2]); ylim([-1 1]);
    xlabel('Radius (in)'); ylabel('Margin of safety (ECSS core shear)');
    legend([mat.name ' plug'], 'Potted (old calc)', 'Location', 'southeast');
    title(sprintf('Link %.0f N, SF %.1f', link_force_N, SF));
    grid on;
end