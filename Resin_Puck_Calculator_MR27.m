%% MRacing MR27 - Resin puck calculator (single script)
% Design: Al spool(s) cast in a Pro-Set LAM-151-HT resin puck, fully cured, then spliced into the
% 6.1 pcf panel core with 3M AF 3074 film and co-cured at 350 F.
%
% OUTPUTS: (1) resin puck radius, (2) each failure mode's required radius and which one governs,
%          (3) the bond strength the core splice must provide.
%
% Everything is in this file: edit the inputs below and run. Units: in, lb, psi (N for the link force).
% Placeholders are marked  <-- PLACEHOLDER  and are repeated in the printout.
% NOTHING here is validated: only axial pull-out has MR25 test calibration, nothing in-plane.
clear; clc;

%% ========================= INPUTS =========================

% --- Loads ---------------------------------------------------------------
load_mode        = 'bracket';   % 'bracket' = link force + bracket geometry, 'direct' = enter puck loads yourself
% 'bracket' mode (MR27 Suspension Loads Rev15, FLCA fore, 8140 N compression)
link_force_N     = 8140;        % max |link force|, N
angle_deg        = 10.45;       % link angle from the panel normal, deg          <-- verify for Rev15
a                = 1.52;        % bolt spacing, in                               <-- verify for Rev15
y                = 0.4185;      % moment arm of the in-plane load above the panel, in <-- verify for Rev15
SF               = 2;           % safety factor on load
bolts_per_bracket = 2;
bolts_in_puck    = 2;           % 2 = both bolts share one puck, 1 = one bolt per puck
puck_shape       = 'figure8';   % for 2 bolts: 'figure8' (two overlapping circles, has cusps) or 'stadium' (slot, no cusps)
use_friction     = true;        % bolt clamp friction carries part of the in-plane load
bolt_preload_lb  = 2125.8;      % per bolt                                        <-- PLACEHOLDER (torque spec gives ~1156 lb)
mu               = 0.2;         % friction coefficient                            <-- PLACEHOLDER (MR26 sheet used 0.175)
% 'direct' mode: total design loads ON THE PUCK, NO safety factor applied here
direct_P_lb      = 1000;        % pull-out (normal) load
direct_Q_lb      = 0;           % in-plane shear
direct_M_lb_in   = 0;           % moment

% --- Panel skins (MR27 layup) --------------------------------------------
n_plies          = 3;           %                                                 <-- PLACEHOLDER (ask composites lead)
t_ply_mm         = 0.18;        %                                                 <-- PLACEHOLDER
vf               = 0.3;         % skin Poisson ratio                              <-- PLACEHOLDER
Ef               = 4.33e6;      % skin modulus, psi                               <-- PLACEHOLDER
sigma_fy         = 14000;       % skin interlaminar shear, psi (v2 value)         <-- PLACEHOLDER
tau_f_punch      = 14000;       % skin punch-out shear strength, psi              <-- PLACEHOLDER
f = n_plies*t_ply_mm/25.4;      % face-sheet thickness, in

% --- Panel core (global 6.1 pcf, Hexcel HexWeb CR-III 5052 1/8-6.1, W direction) ---
c                = 1.0;         % core height, in (confirmed)
Twcrit           = 272;         % plate shear strength W dir, psi: MINIMUM (typical = 340)
G_W              = 41000;       % plate shear modulus W dir, psi
Gc               = G_W;         % decided: Gc = G_W (the old G_W/3 is dropped)

% --- Spool and resin -----------------------------------------------------
flange_OD        = 0.50;        % NAS03 spool flange OD, in
neck_OD          = 0.291;       % NAS03 spool neck OD, in
bolt_bore        = 0.191;       % spool bore, in
neck_yield_psi   = 35000;       % spool neck yield: 6061-T6 minimum, assumed  <-- PLACEHOLDER (confirm spool alloy/temper)
resin_wall_min   = 0.125;       % min resin wall outside the flange, in           <-- PLACEHOLDER
inset_each_face  = 0.0;         % resin inset below each skin, in (resin is slightly inset to fit under skins) <-- PLACEHOLDER

% --- ECSS settings -------------------------------------------------------
Pss_knockdown    = 0.89;        % knockdown on P_crit only (as in v2)
% The resin does not fill the cells, so the puck is a rigid plug: the effective radius is the puck radius.

%% ========================= LOADS ON THE PUCK =========================
switch lower(load_mode)
    case 'bracket'
        F  = link_force_N*0.224809;                 % lb
        Fn = F*cosd(angle_deg);                     % normal to panel (pull-out), whole bracket
        Fs = F*sind(angle_deg);                     % in-plane, whole bracket
        share = bolts_in_puck/bolts_per_bracket;    % fraction of the bracket this puck carries
        friction = bolts_in_puck*bolt_preload_lb*mu*use_friction;
        P = SF*Fn*share;
        Q = max(SF*Fs*share - friction, 0);
        M = SF*Fs*y*share;
    case 'direct'
        P = SF*direct_P_lb;  Q = SF*direct_Q_lb;  M = SF*direct_M_lb_in;
        friction = 0;
    otherwise
        error('load_mode must be ''bracket'' or ''direct''.');
end
if P <= 0, error('P must be > 0.'); end

%% ========================= FAILURE MODES =========================
% Each mode gives the radius of an equivalent ROUND puck (R_eq) that survives. For two bolts sharing
% one puck made of two overlapping circles, R_eq is converted to a lobe radius further down.

% --- 1. ECSS core shear, with the in-plane and moment interaction (equations unchanged from v2) ---
b      = linspace(0.05, 6, 60000);                  % candidate round-puck radii, in
beta   = c/f;                                                           % [C.2-9]
alpha  = 1/f*sqrt(Gc/Ef*12*(1-vf^2)*(1+beta/2));                        % [C.2-10]
C_star = beta/(beta+1);                                                 % [C.2-14]
Kmax   = @(x) x./(x./(1-exp(-.931714.*(alpha.*x).^.262866))) ...
         .*(1-sqrt((x./(1-exp(-.931714.*(alpha.*x).^.262866)))./x) ...
         .*exp(alpha.*(x-x./(1-exp(-.931714.*(alpha.*x).^.262866)))));  % [C.2-16],[C.2-6]
Pcrit  = @(x) 2*pi.*x.*c.*Twcrit./(C_star.*Kmax(x));                    % [C.2-17]
Qss    = @(x) 8*x.^2*Twcrit + 2*f.*x.*sigma_fy;                         % [14.2-1]
Mss    = @(x) Pcrit(x).*x;                                              % Mss = P_crit * b
ms_ecss = @(x) 1 - ((Q./Qss(x)).^2 + (P./(Pss_knockdown*Pcrit(x))).^2 + (M./Mss(x)).^2);
MS = ms_ecss(b);
i  = find(MS >= 0, 1);
if isempty(i), error('ECSS: no radius up to %.1f in works.', max(b)); end
Req_ecss = b(i);

% --- 2. Face-sheet punch-out at the puck edge ---
Req_punch = P/(2*pi*f*tau_f_punch);

% --- 3. Geometry: the puck must hold the spool flange plus a minimum resin wall (per lobe) ---
R_geom = flange_OD/2 + resin_wall_min;

% --- 4. Spool neck compression (a spool check: it does NOT change the puck radius) ---
% Worst case is the push-in direction: bolt preload clamps the neck and the pushed-in link load adds to it.
% The neck is checked ALONE, so any compression the resin shares is ignored (conservative, see printout).
A_neck    = pi/4*(neck_OD^2 - bolt_bore^2);          % in^2
F_neck    = bolt_preload_lb + P/bolts_in_puck;       % lb per spool: preload + equal share of the push-in load
sig_neck  = F_neck/A_neck;                           % psi
MS_neck   = neck_yield_psi/sig_neck - 1;
A_neck_req  = F_neck/neck_yield_psi;                 % neck area needed for MS = 0, in^2
OD_neck_req = sqrt(4*A_neck_req/pi + bolt_bore^2);   % neck OD needed for MS = 0 at this bore, in

%% ========================= TWO OVERLAPPING CIRCLES =========================
% Outline of two circles of radius R with centres a apart. Perimeter and area of the union:
th_f   = @(R) acos(min(a./(2*R), 1));                                        % half-angle lost inside the overlap
per_f  = @(R) 4*R.*(pi - th_f(R));                                           % perimeter of the union
area_f = @(R) 2*pi*R.^2 - (2*R.^2.*th_f(R) - (a/2)*sqrt(max(4*R.^2 - a^2, 0)));  % area of the union
if bolts_in_puck == 2 && strcmpi(puck_shape, 'stadium')
    % Stadium (slot): end radius R at each bolt, straight sides a long. No cusps.
    per_f  = @(R) 2*a + 2*pi*R;
    area_f = @(R) pi*R.^2 + 2*R*a;
    lobe_for = @(Req) max(Req - a/pi, 0);        % same-PERIMETER rule as the figure-8 (ours, NOT ECSS)
elseif bolts_in_puck == 2
    % Lobe radius whose union outline has the same PERIMETER as a round puck of radius R_eq.
    % This is an approximation of ours, NOT ECSS: it ignores the stress concentration at the two cusps.
    Rg = linspace(0.01, 8, 80000);
    lobe_for = @(Req) Rg(find(per_f(Rg) >= 2*pi*Req, 1));
else
    lobe_for = @(Req) Req;                       % one bolt: the puck is just a circle
    per_f  = @(R) 2*pi*R;
    area_f = @(R) pi*R.^2;
end
R_lobe_ecss  = lobe_for(Req_ecss);
R_lobe_punch = lobe_for(Req_punch);
R_lobe_geom  = R_geom;

%% ========================= RESULT: RESIN PUCK RADIUS =========================
modes = {'ECSS core shear (P,Q,M interaction)', 'Face-sheet punch-out', 'Geometry (flange + resin wall)'};
R_req = [R_lobe_ecss, R_lobe_punch, R_lobe_geom];
[R_puck, gov] = max(R_req);                      % puck (lobe) radius to mold, in
Rq_final   = per_f(R_puck)/(2*pi);               % equivalent round radius of the final outline

% Margins at the final size
MS_ecss_f  = ms_ecss(Rq_final);
MS_punch_f = Rq_final/Req_punch - 1;
MS_geom_f  = R_puck/R_geom - 1;
MS_all = [MS_ecss_f, MS_punch_f, MS_geom_f];

%% ========================= RESULT: REQUIRED SPLICE BOND =========================
% Rigid puck bonded to the core on its outline (ours, not ECSS; no splice film test data yet):
h       = c - 2*inset_each_face;                 % bonded wall height (resin is inset below each skin), in
perim   = per_f(R_puck);                         % bonded perimeter, in
tau_avg = P/(perim*h);                           % average axial shear on the wall, psi
tau_pk  = tau_avg + M/(pi*Rq_final^2*h);         % peak axial shear when the moment tilts the puck, psi
sig_Q   = Q/(pi*Rq_final*h);                     % peak normal (peel/compression) stress on the wall from Q, psi

%% ========================= PRINTOUT =========================
fprintf('\n=== MR27 RESIN PUCK CALCULATOR ===\n');
fprintf('Panel: 6.1 pcf core, c = %.2f in, skins %d x %.2f mm (f = %.4f in).  Gc = G_W = %.0f psi, tau_W = %.0f psi (min).\n', ...
    c, n_plies, t_ply_mm, f, Gc, Twcrit);
if strcmpi(load_mode,'bracket')
    fprintf('Loads (%s, SF %.1f, %d of %d bolts in this puck): link %.0f N at %.2f deg, a = %.2f in, y = %.4f in.\n', ...
        load_mode, SF, bolts_in_puck, bolts_per_bracket, link_force_N, angle_deg, a, y);
    fprintf('  Friction credit %.0f lb (use_friction = %d).\n', friction, use_friction);
else
    fprintf('Loads (direct, SF %.1f applied here).\n', SF);
end
fprintf('  Design loads on the puck:  P = %.0f lb (pull-out),  Q = %.0f lb (in-plane),  M = %.0f lb-in\n\n', P, Q, M);

fprintf('--- RESIN PUCK RADIUS ---\n');
if bolts_in_puck == 2
    if strcmpi(puck_shape, 'stadium')
        fprintf('  Stadium (slot) puck: end radius at each bolt %.3f in, centres %.2f in apart, straight sides\n', R_puck, a);
    else
        fprintf('  Radius of each lobe (two overlapping circles, centres %.2f in apart): %.3f in\n', a, R_puck);
    end
    fprintf('  Outline: %.2f in long x %.2f in wide, area %.2f in^2\n', a + 2*R_puck, 2*R_puck, area_f(R_puck));
else
    fprintf('  Puck radius (one round puck): %.3f in  (diameter %.3f in)\n', R_puck, 2*R_puck);
end
fprintf('  (Not rounded: pick your mold/jig size at or above this.)\n\n');

fprintf('--- FAILURE MODES (radius each one needs) ---\n');
fprintf('  %-40s %12s %10s\n', 'Mode', 'Radius (in)', 'Margin');
for k = 1:3
    flag = '';  if k == gov, flag = '  <-- GOVERNS'; end
    fprintf('  %-40s %12.3f %+10.2f%s\n', modes{k}, R_req(k), MS_all(k), flag);
end
fprintf('  (Round-puck equivalents: ECSS %.3f in, punch-out %.3f in. ', Req_ecss, Req_punch);
if bolts_in_puck == 2, fprintf('Radii above come from the equal-perimeter conversion.)\n\n'); else, fprintf(')\n\n'); end

fprintf('--- SPOOL NECK COMPRESSION (does not change the puck radius) ---\n');
fprintf('  Load per spool %.0f lb (preload %.0f + push-in %.0f) on neck area %.4f in^2 -> %.0f psi vs yield %.0f psi\n', ...
    F_neck, bolt_preload_lb, P/bolts_in_puck, A_neck, sig_neck, neck_yield_psi);
if MS_neck >= 0, verdict = 'OK'; else, verdict = 'FAILS (neck alone)'; end
fprintf('  Margin %+.2f  %s.  Neck OD for MS = 0 at a %.3f in bore: %.3f in (now %.3f in; flange OD %.2f in)\n', ...
    MS_neck, verdict, bolt_bore, OD_neck_req, neck_OD, flange_OD);
fprintf('  Checked on the neck alone; the resin around it may share the compression, which this ignores.\n');
fprintf('  Preload is a PLACEHOLDER; the ~1156 lb torque-spec value lowers this check but does not fix it.\n\n');

fprintf('--- SPLICE BOND STRENGTH REQUIRED (on the puck wall, height %.2f in) ---\n', h);
fprintf('  Average axial shear   : %6.0f psi   (P / (perimeter x height))\n', tau_avg);
fprintf('  Peak axial shear      : %6.0f psi   (adds the moment: M / (pi Req^2 h))\n', tau_pk);
fprintf('  Peak normal stress    : %6.0f psi   (from Q: Q / (pi Req h))\n', sig_Q);
fprintf('  -> The splice must carry at least %.0f psi shear (peak) with margin you choose.\n', tau_pk);
fprintf('     For reference: 3M AF 3074 datasheet = 1883 psi on SOLID Al tubes (257 F cure), not honeycomb;\n');
fprintf('     the 6.1 pcf core itself fails in plate shear at %.0f psi. A push-out coupon test is needed.\n\n', Twcrit);

fprintf('--- FLAGS ---\n');
if Q > 0 && Req_ecss > 0.433
    fprintf('  * Qss curve fit is only valid for radius < 0.433 in; Q term is extrapolated here.\n');
end
if Q == 0 && strcmpi(load_mode,'bracket')
    fprintf('  * Friction cancels all of Q, so skin in-plane strength (sigma_fy) did not matter. Friction is a PLACEHOLDER.\n');
end
fprintf('  * PLACEHOLDERS: skin layup (n_plies, t_ply, Ef, vf), sigma_fy, tau_f_punch, bolt preload and mu,\n');
fprintf('    resin_wall_min, inset_each_face, neck_yield_psi, and the Rev15 angle / a / y.\n');
if bolts_in_puck == 2
    if strcmpi(puck_shape, 'stadium')
        fprintf('  * Two-bolt puck sizing is an equal-perimeter approximation (ours, not ECSS).\n');
    else
        fprintf('  * Two-bolt puck sizing is an equal-perimeter approximation (ours, not ECSS); cusp stresses ignored.\n');
    end
end
fprintf('  * Resin LAM-151-HT: onset Tg 328 F is below the 350 F co-cure; no 350 F data. Splice film data is typical/preliminary.\n');
fprintf('  * Not validated: only axial pull-out has MR25 test calibration; nothing in-plane.\n\n');
