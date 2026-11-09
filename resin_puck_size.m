function r = resin_puck_size(p)
%RESIN_PUCK_SIZE  Size a spliced resin puck (Al spool(s) + cured resin) in the panel core.
%   Design (Nov 2026): the spool is cast in a resin puck in a jig and fully cured, then the
%   puck is spliced into the panel core with 3M AF 3074 core splice film and co-cured at 350 F.
%   There is no higher-density core patch: the panel core is the (global 6.1 pcf) core.
%
%   The puck is treated as ONE rigid round insert of radius R_h (hole radius in the core =
%   puck radius + splice gap) carrying the loads of the spools it holds:
%     * ECSS core shear / in-plane / moment interaction in the PANEL core (ecss_core.m,
%       unchanged equations). p.ecss_variant = 'plug' (b everywhere; default, the resin does
%       not fill the cells) or 'potted' (bp = b + 0.35*Sc, the v2 cleared-cell convention).
%     * Face-sheet punch-out at the puck edge (kept from the old calculator; PLACEHOLDER strength).
%     * Geometric floor: the puck must hold the spool flange(s) plus a minimum resin wall.
%   Reported, NOT sized: the bond strength the splice film must provide.
%
%   p.inserts_per_puck = 1  : one puck per spool (neighbouring pucks must fit at the bolt spacing)
%   p.inserts_per_puck = 2  : one ROUND puck shared by the two spools of a bracket, spools at
%                             +/- a/2 from the centre, loads = bracket resultants.
%   The resin is inset from each skin by p.inset_each_face_in, so the resin/splice wall height
%   is h = c - 2*inset (the ECSS core height stays c).
%
%   r.R_p_std is the puck radius to mold; r.R_h_std = R_p_std + gap is the hole radius in the core.
r.ok = true;  r.msg = '';
n_in = p.inserts_per_puck;
if n_in > 2
    error('Shared-puck geometry is only defined for 1 or 2 spools per puck.');
end
L = hardpoint_loads(p);
r.L = L;
Pp = L.Ppk;  Qp = L.Qpk;  Mp = L.Mpk;              % loads on ONE puck
r.Pp = Pp;  r.Qp = Qp;  r.Mp = Mp;

panel = core_lookup(p.core_lib, p.panel_core_name);
cp    = core_props(panel, p.strength_basis, p.Gc_scale);
r.panel = panel;  r.cp = cp;
h = p.c - 2*p.inset_each_face_in;                   % resin / splice wall height
r.h = h;

% --- ECSS core shear of the puck in the panel core (sized at the HOLE radius)
e = ecss_core(cp, p.f, p.Ef, p.vf, p.c, p.ecss_variant, Pp, Qp, Mp, p.Sigma_fy, p.Pss_knockdown, p.bgrid);
r.ecss = e;
other = 'plug';  if strcmp(p.ecss_variant, 'plug'), other = 'potted'; end
eo = ecss_core(cp, p.f, p.Ef, p.vf, p.c, other, Pp, Qp, Mp, p.Sigma_fy, p.Pss_knockdown, p.bgrid);
r.ecss_other = eo;  r.other_variant = other;
if ~e.found
    r.ok = false;
    r.msg = sprintf('No radius under %.1f in satisfies ECSS in the panel core.', max(p.bgrid));
    return
end
r.R_ecss = e.b_eff_req;                             % hole radius from ECSS

r.R_punch = Pp/(2*pi*p.f*p.tau_f_punch);            % skin punch-out at the puck edge
r.R_load  = max(r.R_ecss, r.R_punch);               % hole radius needed by the loads
if n_in > 1
    r.offset = p.a/2;                               % spools sit off-centre in a shared puck
else
    r.offset = 0;
end
r.R_geom  = r.offset + p.spool_flange_OD/2 + p.resin_wall_min;   % PUCK radius floor
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
em = ecss_core(cp, p.f, p.Ef, p.vf, p.c, p.ecss_variant, Pp, Qp, Mp, p.Sigma_fy, p.Pss_knockdown, bin);
r.ms_ecss  = em.MS;
r.ms_punch = Rh/r.R_punch - 1;
r.qss_extrapolated = (Qp > 0) && (Rh > 0.433);
r.qss_core = 8*Rh^2*cp.Twcrit;                      % core term of Qss at Rh
r.qss_skin = 2*p.f*Rh*p.Sigma_fy;                   % skin term of Qss at Rh
r.R_core_skin_equal = p.f*p.Sigma_fy/(4*cp.Twcrit);

% --- Splice bond REQUIRED (reported, not sized). First-principles rigid-puck estimates (ours, not ECSS):
%   average axial shear on a cylindrical wall      tau    = P/(2*pi*R*h)
%   peak axial shear when the moment M tilts it    tau_pk = tau + M/(pi*R^2*h)   (cosine wall shear)
%   peak normal stress on the wall from in-plane Q sigma  = Q/(pi*R*h)           (film in tension on the trailing side)
% Puck side: radius R_p and resin wall height h. Core side: radius R_h and core height c.
r.tau_avg_puck = Pp/(2*pi*Rp*h);
r.tau_avg_core = Pp/(2*pi*Rh*p.c);
r.tau_pk_puck  = r.tau_avg_puck + Mp/(pi*Rp^2*h);
r.tau_pk_core  = r.tau_avg_core + Mp/(pi*Rh^2*p.c);
r.sig_q_puck   = Qp/(pi*Rp*h);
r.sig_q_core   = Qp/(pi*Rh*p.c);

% Allowable bracket (AF 3074 datasheet values are on solid Al tubes, not honeycomb; see splice_lookup.m)
sol = panel.rho_pcf/(p.rho_al_gcc/0.0160185);       % foil solidity of the core = rho_core / rho_Al
r.solidity = sol;
r.allow.names = {'core plate shear (placeholder)', 'foil-edge only (tube shear x solidity)', 'solid Al tube shear (upper bound)'};
r.allow.vals  = [cp.Twcrit, p.splice.tube_shear_73F_psi*sol, p.splice.tube_shear_73F_psi];
if isnumeric(p.splice_allow_basis)
    r.tau_allow = p.splice_allow_basis;  r.allow_basis = 'user value';
else
    switch p.splice_allow_basis
        case 'core',       r.tau_allow = r.allow.vals(1);  r.allow_basis = r.allow.names{1};
        case 'foil_edge',  r.tau_allow = r.allow.vals(2);  r.allow_basis = r.allow.names{2};
        case 'tube_shear', r.tau_allow = r.allow.vals(3);  r.allow_basis = r.allow.names{3};
        otherwise, error('splice_allow_basis must be ''core'', ''foil_edge'', ''tube_shear'' or a number (psi).');
    end
end
r.ms_bond_avg  = r.tau_allow*p.splice_knockdown/r.tau_avg_puck - 1;
r.ms_bond_peak = r.tau_allow*p.splice_knockdown/r.tau_pk_puck  - 1;
r.allow.ms_avg  = r.allow.vals*p.splice_knockdown/r.tau_avg_puck - 1;
r.allow.ms_peak = r.allow.vals*p.splice_knockdown/r.tau_pk_puck  - 1;

% --- Puck-to-puck spacing (one puck per spool, bolts of one bracket); geometry only
if n_in == 1 && p.inserts_per_bracket > 1
    r.spacing_min = 2*Rh + p.min_ligament;
    r.ms_spacing  = p.a/r.spacing_min - 1;
else
    r.spacing_min = NaN;  r.ms_spacing = NaN;
end

% --- Mass (resin + spool(s) + splice film, minus the panel core removed)
pm = p;  pm.mat = struct('rho_gcc', NaN);           % insert_mass also returns a plug mass; unused here
mi = insert_mass(pm, Rp, Rp);                       % one spool + resin filling a radius-Rp cylinder of height c
solid_one = pi*Rp^2*p.c - mi.V_potting;             % in^3 of the c-high cylinder taken by one spool and its bore
V_resin = (pi*Rp^2 - n_in*solid_one/p.c)*h;         % in^3 of resin (inset applied to the height; approximate)
m_resin = p.rho_potting_gcc*16.387064/1000*V_resin;
film = p.splice_film_kgm2*(2*pi*Rh*p.c*0.0254^2);   % kg, film on the hole wall (applied weight; mass is conserved when it foams)
disp_core = panel.rho_pcf*0.0160185*16.387064/1000*(pi*Rh^2*p.c);   % kg of panel core removed
r.mass.spool = n_in*mi.spool;  r.mass.resin = m_resin;  r.mass.film = film;
r.mass.gross = r.mass.spool + m_resin + film;
r.mass.displaced = disp_core;
r.mass.net = r.mass.gross - disp_core;
r.pucks_per_bracket = p.inserts_per_bracket/n_in;
r.mass.net_per_bracket   = r.mass.net*r.pucks_per_bracket;
r.mass.gross_per_bracket = r.mass.gross*r.pucks_per_bracket;
r.mass.V_resin = V_resin;
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
