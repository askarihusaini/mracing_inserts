function r = size_hardpoint(p)
%SIZE_HARDPOINT  Size inserts (and the puck) for one hardpoint. No printing.
%   Two sizing paths are returned side by side:
%     r.leg : "no puck" legacy path - the insert sized directly in the PANEL core
%             (this reproduces the original script's numbers exactly).
%     r.t.plug / r.t.potted : two-level design - insert sized in the PUCK core,
%             puck radius R sized in the PANEL core as one large rigid insert,
%             plus masses and margins, for BOTH insert types.
%   r.sel is the type chosen by p.insert_type ('potted' or 'plug').
%   All core data, layup, plug properties, punch strength, bond allowables etc. that
%   are flagged PLACEHOLDER in the main script feed straight through.
r.ok = true;  r.msg = '';
L = hardpoint_loads(p);
r.L = L;

panel = core_lookup(p.core_lib, p.panel_core_name);
puck  = core_lookup(p.core_lib, p.puck_core_name);
cp_panel = core_props(panel, p.strength_basis, p.Gc_scale);
cp_puck  = core_props(puck,  p.strength_basis, p.Gc_scale);
r.panel = panel;  r.puck = puck;  r.cp_panel = cp_panel;  r.cp_puck = cp_puck;

%% (A) Legacy: insert sized directly in the panel core (no puck)
r.leg = size_insert(p, cp_panel, L.P, L.Q, L.M, L.Q_bearing);
if ~r.leg.ok
    r.ok = false;  r.msg = 'No insert radius under the grid limit satisfies ECSS in the PANEL core.';
    return
end

%% (B) Two-level: insert in puck core
pk = size_insert(p, cp_puck, L.P, L.Q, L.M, L.Q_bearing);
r.pk = pk;
if ~pk.ok
    r.ok = false;  r.msg = 'No insert radius under the grid limit satisfies ECSS in the PUCK core.';
    return
end

% Puck radius R: the puck is one large rigid insert in the PANEL core carrying all the
% load of the inserts it holds (ECSS check with panel core properties).
Rres = ecss_core(cp_panel, p.f, p.Ef, p.vf, p.c, 'plug', L.Ppk, L.Qpk, L.Mpk, ...
                 p.Sigma_fy, p.Pss_knockdown, p.Rgrid);
r.puck_ecss = Rres;
if Rres.found
    r.R_ecss = Rres.b_req;
else
    r.R_ecss = Inf;                      % no solution inside the R grid
end
if p.inserts_per_puck > 1
    offset = p.a/2;                      % inserts sit off-centre in a shared puck
else
    offset = 0;
end
r.offset = offset;

types = {'plug', 'potted'};
for k = 1:2
    ty = types{k};
    if strcmp(ty, 'plug'), b_exact = pk.b_design; else, b_exact = pk.bp_potted; end
    t.kind    = ty;
    t.b_exact = b_exact;
    if p.round_to_std
        [t.b_ab, t.b_beyond] = pick_std(p.std_sizes, b_exact);
    else
        t.b_ab = b_exact;  t.b_beyond = false;
    end
    t.R_geom = offset + t.b_ab + p.puck_wall_min;
    t.R_req  = max(r.R_ecss, t.R_geom);
    t.R_geom_governs = t.R_geom > r.R_ecss;
    if p.round_to_std && isfinite(t.R_req)
        [t.R_ab, t.R_beyond] = pick_std(p.std_puck_R, t.R_req);
    else
        t.R_ab = t.R_req;  t.R_beyond = false;
    end

    % Margins at the as-built sizes
    t.m = insert_margins(p, ty, cp_puck, L.P, L.Q, L.M, L.Q_bearing, t.b_ab);
    t.geom_ms = t.R_ab/t.R_geom - 1;     % (b + wall <= R)
    t.tau_splice_req = L.Ppk/(2*pi*t.R_ab*p.c);
    if isempty(p.tau_splice_allow)
        t.tau_splice_allow = cp_panel.Twcrit;
    else
        t.tau_splice_allow = p.tau_splice_allow;
    end
    t.splice_ms = t.tau_splice_allow/t.tau_splice_req - 1;
    if isfinite(t.R_ab)
        Rchk = ecss_core(cp_panel, p.f, p.Ef, p.vf, p.c, 'plug', L.Ppk, L.Qpk, L.Mpk, ...
                         p.Sigma_fy, p.Pss_knockdown, t.R_ab);
        t.puck_ecss_ms = Rchk.MS;
    else
        t.puck_ecss_ms = NaN;
    end

    % Mass: puck core + splice film + insert(s) - panel core displaced
    if strcmp(ty, 'plug')
        mi = insert_mass(p, t.b_ab, pk.bp_potted);
        m_ins = mi.plug;   r_ins = t.b_ab;
    else
        mi = insert_mass(p, pk.b_design, t.b_ab);
        m_ins = mi.potted; r_ins = t.b_ab;
    end
    t.mass = puck_mass(p, panel, puck, t.R_ab, r_ins, m_ins);
    t.mass.ins = mi;
    r.t.(ty) = t;
end
r.sel = r.t.(p.insert_type);
end

%% -------------------------------------------------------------------------
function s = size_insert(p, cp, P, Q, M, Qb)
% Radii by failure mode for plug and potted insert in core cp (baseline logic).
s.ok = true;
ep = ecss_core(cp, p.f, p.Ef, p.vf, p.c, 'plug',   P, Q, M, p.Sigma_fy, p.Pss_knockdown, p.bgrid);
eo = ecss_core(cp, p.f, p.Ef, p.vf, p.c, 'potted', P, Q, M, p.Sigma_fy, p.Pss_knockdown, p.bgrid);
s.ecss_plug = ep;  s.ecss_pot = eo;
if ~(ep.found && eo.found)
    s.ok = false;
    return
end
s.b_ecss  = ep.b_req;          % plug radius from ECSS core shear
s.bp_ecss = eo.b_eff_req;      % potting radius from ECSS core shear (= old calc result)

% (d) face-sheet punch-out around the perimeter, (e) edge distance
s.b_punch = P/(2*pi*p.f*p.tau_f_punch);
s.b_edge  = p.eD_min*p.d_hole;

s.req_names = {'ECSS core shear (old calc eqns)', 'Face-sheet punch-out', ...
               'Edge distance', 'Minimum radius floor'};
s.req_vals  = [s.b_ecss, s.b_punch, s.b_edge, p.b_min];
[s.b_req, s.igov] = max(s.req_vals);

s.pot_names = {'ECSS core shear (old calc eqns)', 'Face-sheet punch-out (not in old calc)', ...
               'Minimum radius floor'};
s.pot_vals  = [s.bp_ecss, s.b_punch, p.b_min];
[s.bp_potted, s.igov_pot] = max(s.pot_vals);

if p.b_step > 0
    s.b_design = ceil(s.b_req/p.b_step - 1e-9)*p.b_step;
else
    s.b_design = s.b_req;      % first grid radius with MS >= 0
end

s.m_plug = insert_margins(p, 'plug',   cp, P, Q, M, Qb, s.b_design);
s.m_pot  = insert_margins(p, 'potted', cp, P, Q, M, Qb, s.bp_potted);
s.mass   = insert_mass(p, s.b_design, s.bp_potted);
s.qss_extrapolated = (Q > 0) && (s.b_req > 0.433 || s.bp_potted > 0.433);
s.P = P;  s.Q = Q;  s.M = M;
end

%% -------------------------------------------------------------------------
function pm = puck_mass(p, panel, puck, R, r_ins, m_ins)
% Mass of one puck holding p.inserts_per_puck inserts, net of the panel core it replaces.
in3_to_cc = 16.387064;
pcf_to_gcc = 0.0160185;
n = p.inserts_per_puck;
Vcyl     = pi*R^2*p.c;                                   % in^3, cylinder the puck occupies
Vins_cyl = n*pi*r_ins^2*p.c;                             % in^3 of puck volume taken by inserts
pm.puck_core = puck.rho_pcf*pcf_to_gcc*in3_to_cc/1000*(Vcyl - Vins_cyl);   % kg
pm.film      = p.splice_film_kgm2*(2*pi*R*p.c*0.0254^2);                   % kg (splice film on the cylinder wall)
pm.inserts   = n*m_ins;                                                    % kg
pm.displaced = panel.rho_pcf*pcf_to_gcc*in3_to_cc/1000*Vcyl;               % kg panel core removed
pm.gross     = pm.puck_core + pm.film + pm.inserts;
pm.net       = pm.gross - pm.displaced;
pm.net_per_insert = pm.net/n;
pm.pucks_per_bracket = p.inserts_per_bracket/p.inserts_per_puck;
pm.net_per_bracket   = pm.net*pm.pucks_per_bracket;
pm.gross_per_bracket = pm.gross*pm.pucks_per_bracket;
end

%% -------------------------------------------------------------------------
function cp = core_props(core, basis, Gc_scale)
cp.name   = core.name;
cp.rho_pcf = core.rho_pcf;
cp.Sc     = core.cell_in;
cp.GW     = core.GW;
cp.Gc     = core.GW*Gc_scale;      % Gc = G_W (Gc_scale = 1). Only a sensitivity knob, not a convention.
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
