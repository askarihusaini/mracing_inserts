function m = insert_margins(p, kind, cp, P, Q, M, Qb, b)
%INSERT_MARGINS  Margin of safety for every failure mode of one insert at radius b.
%   kind  'plug'   : b = plug radius
%         'potted' : b = POTTING radius bp (inner radius bi = bp - 0.35*Sc)
%   cp    core the insert sits in (panel core, or puck core when a puck is used)
%   P,Q,M design loads per insert; Qb = shear used for plug bolt bearing.
%
%   MS > 0 passes. Definitions:
%     ecss      : 1 - sum of squared ECSS ratios (NOT a load ratio; keeps the
%                 definition of the original script)
%     others    : capacity/demand - 1 (load-ratio style)
%   Fields not applicable to the insert type are NaN.
%   Values flagged PLACEHOLDER in the main script (tau_f_punch, sigma_fy, bond
%   allowable, plug material, eD_min, preloads) propagate into these margins.
mat = p.mat;

if strcmp(kind, 'potted')
    bin = max(b - 0.35*cp.Sc, 1e-3);
else
    bin = b;
end
e = ecss_core(cp, p.f, p.Ef, p.vf, p.c, kind, P, Q, M, p.Sigma_fy, p.Pss_knockdown, bin);
m.ecss = e.MS;
m.qss_extrapolated = (Q > 0) && (b > 0.433);

m.b_punch = P/(2*pi*p.f*p.tau_f_punch);
m.punch   = b/m.b_punch - 1;               % capacity is proportional to b

if isempty(p.tau_bond_allow)
    tau_allow = cp.Twcrit;                 % default: core fails before the bond
else
    tau_allow = p.tau_bond_allow;
end
m.tau_bond_allow = tau_allow;
m.tau_bond_req   = P/(2*pi*b*p.c);
m.bond           = tau_allow*p.bond_knockdown/m.tau_bond_req - 1;

m.edge = NaN;  m.washer = NaN;  m.bearing = NaN;  m.punchthru = NaN;
m.neck = NaN(1, numel(p.neck_preloads));  m.neck_sigma = m.neck;

if strcmp(kind, 'plug')
    m.b_edge   = p.eD_min*p.d_hole;
    m.edge     = b/m.b_edge - 1;
    A_washer   = pi/4*(p.d_washer^2 - p.d_hole^2);
    m.washer   = mat.Fcu_flat/(max(p.bolt_preload, P)/A_washer) - 1;   % flatwise crush under washer
    m.bearing  = mat.Fbru/(Qb/(p.d_bolt*p.c)) - 1;                     % bolt bearing, plug only
    m.punchthru = (pi*p.d_washer*p.c*mat.Fsu_perp)/P - 1;              % washer punching through plug
else
    % Spool neck, neck-only compression: (F_pre + P) / neck area vs 6061-T6 compressive yield.
    % The potting shares compression in reality, so a FAIL here is the expected, known result.
    A_neck = pi/4*(p.spool_neck_dia^2 - p.spool_hole_dia^2);
    m.A_neck = A_neck;
    for k = 1:numel(p.neck_preloads)
        m.neck_sigma(k) = (p.neck_preloads(k) + P)/A_neck;
        m.neck(k)       = p.sigma_cy_al/m.neck_sigma(k) - 1;
    end
end

% Flat name/value list for tables
names = {'ECSS core shear interaction (1 - sum sq)', 'Face-sheet punch-out', ...
         'Insert-to-core bond (placeholder allowable)'};
vals  = [m.ecss, m.punch, m.bond];
if strcmp(kind, 'plug')
    names = [names, {'Edge distance', 'Washer crush (flatwise)', 'Bolt bearing in plug', 'Washer punch-through'}];
    vals  = [vals, m.edge, m.washer, m.bearing, m.punchthru];
else
    for k = 1:numel(p.neck_preloads)
        names{end+1} = sprintf('Spool neck compression, neck-only (preload %.0f lb)', p.neck_preloads(k)); %#ok<AGROW>
        vals(end+1)  = m.neck(k); %#ok<AGROW>
    end
end
m.names = names;
m.vals  = vals;
end
