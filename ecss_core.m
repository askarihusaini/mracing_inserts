function out = ecss_core(cp, f, Ef, vf, c, insert_type, P, Q, M, sigma_fy, knock, b)
%ECSS_CORE  ECSS-E-HB-32-22A core-shear check for one insert / puck in a sandwich panel.
%   Equations are UNCHANGED from Insert_calculator_2025_v2_1.mlx and the original
%   G7 script: beta [C.2-9], alpha [C.2-10], C* [C.2-14], r_tmax fit [C.2-16],
%   K_max [C.2-6], P_crit [C.2-17], Qss [14.2-1], Mss = P_crit*b_i, and the
%   interaction (Q/Qss)^2 + (P/(knock*Pcrit))^2 + (M/Mss)^2 <= 1.
%
%   cp           core struct with fields Gc (psi), Twcrit (psi), Sc (in)
%   f, Ef, vf    face-sheet thickness (in), modulus (psi), Poisson ratio
%   c            core height (in)
%   insert_type  'plug'   : radius b everywhere
%                'potted' : effective radius bp = b + 0.35*Sc, Mss uses b (v2 convention)
%   P, Q, M      design loads (lb, lb, lb-in), SF already applied
%   sigma_fy     skin interlaminar shear strength (psi)  [placeholder: 14 ksi from v2]
%   knock        knockdown on P only (0.89 in v2); Mss does not get it
%   b            vector of candidate (inner) radii, in
%
%   out.MS       margin 1 - (sum of squared ratios) at each b
%   out.b_eff    effective radius used in the capacities (b or bp)
%   out.found    true if any b gives MS >= 0
%   out.b_req    first b with MS >= 0 (NaN if none);  out.b_eff_req likewise for b_eff
%
%   NOTE: the Qss fit is only valid for bp < 0.433 in (v2 comment). Larger radii
%   are extrapolated; out.qss_extrapolated flags this at the answer.

Gc = cp.Gc;  Twcrit = cp.Twcrit;  Sc = cp.Sc;

beta   = c/f;                                                 % [C.2-9]
alpha  = 1/f * sqrt(Gc/Ef*12*(1-vf^2)*(1+beta/2));            % [C.2-10]
C_star = beta/(beta+1);                                       % [C.2-14]
Kmax   = @(x) x./(x./(1-exp(-.931714.*(alpha.*x).^.262866))) ...
            .*(1-sqrt((x./(1-exp(-.931714.*(alpha.*x).^.262866)))./x) ...
            .*exp(alpha.*(x-x./(1-exp(-.931714.*(alpha.*x).^.262866)))));  % [C.2-16],[C.2-6]
Pcrit  = @(x) 2*pi.*x.*c.*Twcrit./(C_star.*Kmax(x));          % [C.2-17]
Qss    = @(x) 8*x.^2*Twcrit + 2*f.*x.*sigma_fy;               % [14.2-1]

switch lower(insert_type)
    case 'plug'
        be = b;
    case 'potted'
        be = b + 0.35*Sc;
    otherwise
        error('ecss_core: insert_type must be ''plug'' or ''potted''.');
end

MS = 1 - ((Q./Qss(be)).^2 + (P./(knock*Pcrit(be))).^2 + (M./(Pcrit(be).*b)).^2);

i1 = find(MS >= 0, 1);
out.b      = b;
out.b_eff  = be;
out.MS     = MS;
out.found  = ~isempty(i1);
out.alpha  = alpha;
if out.found
    out.idx        = i1;
    out.b_req      = b(i1);
    out.b_eff_req  = be(i1);
else
    out.idx        = [];
    out.b_req      = NaN;
    out.b_eff_req  = NaN;
end
out.qss_extrapolated = out.found && (out.b_eff_req > 0.433);
end
