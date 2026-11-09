function r = resin_puck_size(p)
%RESIN_PUCK_SIZE  Size a spliced resin puck (Al spool + cured resin) in the panel core.
%   Design (Nov 2026): the spool is cast in a resin puck in a jig and fully cured, then the
%   puck is spliced into the panel core with 3M AF 3074 core splice film and co-cured at 350 F.
%   There is no higher-density core patch: the panel core is the (global) core.
%
%   The puck is treated as ONE rigid insert of radius R_h (the radius of the hole cut in the
%   core = puck radius + splice gap) carrying the loads of ONE spool:
%     * ECSS core shear / in-plane / moment interaction in the PANEL core (ecss_core.m,
%       unchanged equations). p.ecss_variant = 'plug' (b everywhere; default, rigid puck bonded
%       on its wall) or 'potted' (bp = b + 0.35*Sc, the v2 cleared-cell convention).
%     * Face-sheet punch-out at the puck edge (kept from the old calculator; PLACEHOLDER strength).
%     * Geometric floor: the puck must hold the spool flange plus a minimum resin wall.
%   Reported, NOT sized: the bond strength the splice film must provide.
%
%   r.R_p_std is the puck radius to mold; r.R_h_std = R_p_std + gap is the hole radius in the core.
%   Every field flagged PLACEHOLDER in the main script feeds straight through.
r.ok = true;  r.msg = '';
L = hardpoint_loads(p);
r.L = L;
P = L.P;  Q = L.Q;  M = L.M;                       % per spool = per puck

panel = core_lookup(p.core_lib, p.panel_core_name);
cp    = core_props(panel, p.strength_basis, p.Gc_scale);
r.panel = panel;  r.cp = cp;

% --- ECSS core shear of the puck in the panel core (sized at the HOLE radius)
e = ecss_core(cp, p.f, p.Ef, p.vf, p.c, p.ecss_variant, P, Q, M, p.Sigma_fy, p.Pss_knockdown, p.bgrid);
r.ecss = e;
% Same loads with the other convention, for comparison only
other = 'plug';  if strcmp(p.ecss_variant, 'plug'), other = 'potted'; end
eo = ecss_core(cp, p.f, p.Ef, p.vf, p.c, other, P, Q, M, p.Sigma_fy, p.Pss_knockdown, p.bgrid);
r.ecss_other = eo;  r.other_variant = other;
if ~e.found
    r.ok = false;
    r.msg = sprintf('No radius under %.1f in satisfies ECSS in the panel core.', max(p.bgrid));
    return
end
r.R_ecss = e.b_eff_req;                             % hole radius from ECSS

r.R_punch = P/(2*pi*p.f*p.tau_f_punch);             % skin punch-out at the puck edge
r.R_load  = max(r.R_ecss, r.R_punch);               % hole radius needed by the loads
r.R_geom  = p.spool_flange_OD/2 + p.resin_wall_min; % PUCK radius floor (spool flange + resin wall)
r.R_p_req = max([r.R_load - p.splice_gap_in, r.R_geom, p.b_min]);
if r.R_p_req == r.R_geom && r.R_geom >= r.R_load - p.splice_gap_in
    r.gov = 'geometry (spool flange + resin wall)';
elseif r.R_ecss >= r.R_punch
    r.gov = 'ECSS core shear';
else
    r.gov = 'face-sheet punch-out';
end

if p.round_to_std
    [r.R_p_std, r.beyond_std] = pick_std(p.std_puck_R, r.R_p_req);
else
    r.R_p_std = r.R_p_req;  r.beyond_std = false;
end
r.R_h_std = r.R_p_std + p.splice_gap_in;            % hole radius in the core
Rp = r.R_p_std;  Rh = r.R_h_std;

% --- Margins at the as-built size
if strcmp(p.ecss_variant, 'potted'), bin = max(Rh - 0.35*cp.Sc, 1e-3); else, bin = Rh; end
em = ecss_core(cp, p.f, p.Ef, p.vf, p.c, p.ecss_variant, P, Q, M, p.Sigma_fy, p.Pss_knockdown, bin);
r.ms_ecss  = em.MS;
r.ms_punch = Rh/r.R_punch - 1;
r.qss_extrapolated = (Q > 0) && (Rh > 0.433);
r.qss_core = 8*Rh^2*cp.Twcrit;                      % core term of Qss at Rh
r.qss_skin = 2*p.f*Rh*p.Sigma_fy;                   % skin term of Qss at Rh
r.R_core_skin_equal = p.f*p.Sigma_fy/(4*cp.Twcrit);

% --- Splice bond REQUIRED (reported, not sized). First-principles rigid-puck estimates (ours, not ECSS):
%   average axial shear on a cylindrical wall      tau   = P/(2*pi*R*c)          (project convention)
%   peak axial shear when the moment M tilts it    tau_pk = tau + M/(pi*R^2*c)   (cosine wall shear)
%   peak normal stress on the wall from in-plane Q sigma  = Q/(pi*R*c)           (film in tension on the trailing side)
% Evaluated on the puck side (R_p, smaller area, higher stress) and on the core side (R_h).
r.tau_avg_puck = P/(2*pi*Rp*p.c);
r.tau_avg_core = P/(2*pi*Rh*p.c);
r.tau_pk_puck  = r.tau_avg_puck + M/(pi*Rp^2*p.c);
r.tau_pk_core  = r.tau_avg_core + M/(pi*Rh^2*p.c);
r.sig_q_puck   = Q/(pi*Rp*p.c);
r.sig_q_core   = Q/(pi*Rh*p.c);
if isempty(p.tau_splice_allow)
    r.tau_allow = cp.Twcrit;                        % placeholder: core fails before the splice
    r.allow_is_placeholder = true;
else
    r.tau_allow = p.tau_splice_allow;
    r.allow_is_placeholder = false;
end
r.ms_bond_avg  = r.tau_allow*p.splice_knockdown/r.tau_avg_puck - 1;
r.ms_bond_peak = r.tau_allow*p.splice_knockdown/r.tau_pk_puck  - 1;

% --- Puck-to-puck spacing (bolts of one bracket); geometry only
if p.inserts_per_bracket > 1
    r.spacing_min = 2*Rh + p.min_ligament;
    r.ms_spacing  = p.a/r.spacing_min - 1;
else
    r.spacing_min = NaN;  r.ms_spacing = NaN;
end

% --- Mass (resin + spool + splice film, minus the panel core removed)
pm = p;  pm.mat = struct('rho_gcc', NaN);           % insert_mass also returns a plug mass; unused here
mi = insert_mass(pm, Rp, Rp);                       % spool + resin filling radius Rp
film = p.splice_film_kgm2*(2*pi*Rh*p.c*0.0254^2);   % kg, film on the hole wall (areal weight PLACEHOLDER)
disp_core = panel.rho_pcf*0.0160185*16.387064/1000*(pi*Rh^2*p.c);   % kg of panel core removed
r.mass.spool = mi.spool;  r.mass.resin = mi.potting;  r.mass.film = film;
r.mass.gross = mi.potted + film;
r.mass.displaced = disp_core;
r.mass.net = r.mass.gross - disp_core;
r.mass.net_per_bracket = r.mass.net*p.inserts_per_bracket;
r.mass.gross_per_bracket = r.mass.gross*p.inserts_per_bracket;
r.mass.V_resin = mi.V_potting;
end

%% -------------------------------------------------------------------------
function cp = core_props(core, basis, Gc_scale)
cp.name    = core.name;
cp.rho_pcf = core.rho_pcf;
cp.Sc      = core.cell_in;
cp.GW      = core.GW;
cp.Gc      = core.GW*Gc_scale;      % Gc = G_W (Gc_scale = 1). Sensitivity knob only, not a convention.
if strcmp(basis, 'typ')
    cp.Twcrit = core.tauW_typ;
else
    cp.Twcrit = core.tauW_min;
end
end

%% -------------------------------------------------------------------------
function [v, beyond] = pick_std(list, x)
% Smallest standard size >= x. Beyond the list: round up to the next 0.125 in.
i = find(list >= x - 1e-9, 1);
if isempty(i)
    v = ceil(x/0.125 - 1e-9)*0.125;
    beyond = true;
else
    v = list(i);
    beyond = false;
end
end
