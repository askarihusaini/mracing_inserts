function r = resin_puck_size(p)
%RESIN_PUCK_SIZE  Size a spliced resin puck (Al spool(s) + cured resin) in the panel core.
%   Design (Nov 2026): the spool is cast in a resin puck in a jig and fully cured, then the
%   puck is spliced into the panel core with 3M AF 3074 core splice film and co-cured at 350 F.
%   There is no higher-density core patch: the panel core is the (global 6.1 pcf) core.
%
%   The puck is treated as ONE rigid insert carrying the loads of the spools it holds:
%     * ECSS core shear / in-plane / moment interaction in the PANEL core (ecss_core.m,
%       unchanged equations). p.ecss_variant = 'plug' (b everywhere; default, the resin does
%       not fill the cells) or 'potted' (bp = b + 0.35*Sc, the v2 cleared-cell convention).
%     * Face-sheet punch-out at the puck edge (kept from the old calculator; PLACEHOLDER strength).
%     * Geometric floor: the puck must hold the spool flange(s) plus a minimum resin wall.
%   Reported, NOT sized: the bond strength the splice film must provide.
%
%   p.puck_layout (with p.inserts_per_puck = 1 or 2):
%     'separate' : one round puck per spool; neighbouring pucks must fit at the bolt spacing a.
%     'shared'   : ONE big round puck holding both spools at +/- a/2 from its centre.
%     'overlap'  : two overlapping circles (one lobe per spool, centres a apart), a "figure-8" outline.
%   ECSS is derived for a single CIRCULAR insert. For 'overlap' this code uses an equal-PERIMETER
%   equivalent circle: the union outline must have at least the perimeter of the circle that ECSS
%   needs for the total load. That is an approximation of ours, NOT ECSS, and it ignores the stress
%   concentration at the two re-entrant cusps where the circles meet.
%
%   The resin is inset from each skin by p.inset_each_face_in, so the resin/splice wall height
%   is h = c - 2*inset (the ECSS core height stays c).
%
%   r.R_p_std = puck (lobe) radius to mold; r.R_h_std = R_p_std + gap = hole (lobe) radius in the core.
r.ok = true;  r.msg = '';
n_in = p.inserts_per_puck;
if n_in > 2
    error('Shared-puck geometry is only defined for 1 or 2 spools per puck.');
end
overlap = strcmpi(p.puck_layout, 'overlap') && n_in == 2;
L = hardpoint_loads(p);
r.L = L;
Pp = L.Ppk;  Qp = L.Qpk;  Mp = L.Mpk;              % loads on ONE puck
r.Pp = Pp;  r.Qp = Qp;  r.Mp = Mp;

panel = core_lookup(p.core_lib, p.panel_core_name);
cp    = core_props(panel, p.strength_basis, p.Gc_scale);
r.panel = panel;  r.cp = cp;
h = p.c - 2*p.inset_each_face_in;                   % resin / splice wall height
r.h = h;
r.overlap = overlap;

% --- ECSS core shear of the puck in the panel core (equivalent CIRCLE radius, at the HOLE)
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
r.R_ecss  = e.b_eff_req;                            % equivalent-circle hole radius from ECSS
r.R_punch = Pp/(2*pi*p.f*p.tau_f_punch);            % skin punch-out at the puck edge (perimeter-equivalent)
r.R_load  = max(r.R_ecss, r.R_punch);               % equivalent-circle hole radius needed by the loads

if n_in > 1 && ~overlap
    r.offset = p.a/2;                               % spools sit off-centre in the shared round puck
else
    r.offset = 0;                                   % centred (single, or the lobes of an overlap puck)
end
r.R_geom = r.offset + p.spool_flange_OD/2 + p.resin_wall_min;   % PUCK (lobe) radius floor

if overlap
    R_hole_needed = lobe_radius_for_Req(r.R_load, p.a);   % lobe hole radius whose union outline matches R_load
else
    R_hole_needed = r.R_load;
end
r.R_hole_needed = R_hole_needed;
r.R_p_req = max([R_hole_needed - p.splice_gap_in, r.R_geom, p.b_min]);
if r.R_p_req == r.R_geom && r.R_geom >= R_hole_needed - p.splice_gap_in
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
r.R_h_std = r.R_p_std + p.splice_gap_in;            % hole (lobe) radius in the core
Rp = r.R_p_std;  Rh = r.R_h_std;

% --- Outline geometry of the puck (p) and the hole (h): perimeter, area, equivalent radius
if overlap
    [r.per_p, r.area_p, r.Req_p] = lobes(Rp, p.a);
    [r.per_h, r.area_h, r.Req_h] = lobes(Rh, p.a);
    r.lobes_overlap = (2*Rh > p.a);
    r.length_h = p.a + 2*Rh;  r.width_h = 2*Rh;
else
    r.per_p = 2*pi*Rp;  r.area_p = pi*Rp^2;  r.Req_p = Rp;
    r.per_h = 2*pi*Rh;  r.area_h = pi*Rh^2;  r.Req_h = Rh;
    r.lobes_overlap = false;
    r.length_h = 2*Rh;  r.width_h = 2*Rh;
end

% --- Margins at the as-built size (evaluated at the equivalent circle)
Rq = r.Req_h;
if strcmp(p.ecss_variant, 'potted'), bin = max(Rq - 0.35*cp.Sc, 1e-3); else, bin = Rq; end
em = ecss_core(cp, p.f, p.Ef, p.vf, p.c, p.ecss_variant, Pp, Qp, Mp, p.Sigma_fy, p.Pss_knockdown, bin);
r.ms_ecss  = em.MS;
r.ms_punch = Rq/r.R_punch - 1;
r.qss_extrapolated = (Qp > 0) && (Rq > 0.433);
r.qss_core = 8*Rq^2*cp.Twcrit;                      % core term of Qss at the equivalent radius
r.qss_skin = 2*p.f*Rq*p.Sigma_fy;                   % skin term of Qss at the equivalent radius
r.R_core_skin_equal = p.f*p.Sigma_fy/(4*cp.Twcrit);

% --- Splice bond REQUIRED (reported, not sized). First-principles rigid-puck estimates (ours, not ECSS):
%   average axial shear on the wall               tau    = P/(perimeter*h)
%   peak axial shear when the moment M tilts it   tau_pk = tau + M/(pi*Req^2*h)   (cosine wall shear)
%   peak normal stress on the wall from Q         sigma  = Q/(pi*Req*h)            (film in tension on the trailing side)
% Puck side: puck outline and resin wall height h. Core side: hole outline and core height c.
r.tau_avg_puck = Pp/(r.per_p*h);
r.tau_avg_core = Pp/(r.per_h*p.c);
r.tau_pk_puck  = r.tau_avg_puck + Mp/(pi*r.Req_p^2*h);
r.tau_pk_core  = r.tau_avg_core + Mp/(pi*r.Req_h^2*p.c);
r.sig_q_puck   = Qp/(pi*r.Req_p*h);
r.sig_q_core   = Qp/(pi*r.Req_h*p.c);

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
mi = insert_mass(pm, 0.5, 0.5);                     % spool volumes for a reference radius (solid_one below is radius-independent)
solid_one = pi*0.5^2*p.c - mi.V_potting;            % in^3 of a c-high cylinder taken by one spool and its bore
V_resin = (r.area_p - n_in*solid_one/p.c)*h;        % in^3 of resin (inset applied to the height; approximate)
m_resin = p.rho_potting_gcc*16.387064/1000*V_resin;
film = p.splice_film_kgm2*(r.per_h*p.c*0.0254^2);   % kg, film on the hole wall (applied weight; mass is conserved when it foams)
disp_core = panel.rho_pcf*0.0160185*16.387064/1000*(r.area_h*p.c);   % kg of panel core removed
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
function [per, area, Req] = lobes(Rc, a)
% Outline of two circles of radius Rc with centres a apart (union).
if 2*Rc <= a                                   % separate or tangent
    per  = 4*pi*Rc;
    area = 2*pi*Rc^2;
else
    th   = acos(a/(2*Rc));                     % half-angle of the arc lost inside the overlap
    per  = 4*Rc*(pi - th);
    lens = 2*Rc^2*th - (a/2)*sqrt(4*Rc^2 - a^2);
    area = 2*pi*Rc^2 - lens;
end
Req = per/(2*pi);
end

%% -------------------------------------------------------------------------
function Rc = lobe_radius_for_Req(Rreq, a)
% Smallest lobe radius whose union outline has equivalent radius (perimeter/2pi) >= Rreq. Bisection.
lo = 1e-3;  hi = Rreq;                         % at Rc = Rreq the perimeter is already >= 2*pi*Rreq
for k = 1:80
    mid = 0.5*(lo + hi);
    [~, ~, Req] = lobes(mid, a);
    if Req >= Rreq, hi = mid; else, lo = mid; end
end
Rc = hi;
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
