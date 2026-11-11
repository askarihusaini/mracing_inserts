function m = insert_mass(p, b_plug, bp_pot)
%INSERT_MASS  Plug mass and potted (Al spool + potting) mass in kg.
%   Same arithmetic as the original script. Spool length is the full panel
%   thickness (2f + c). Potting fills the core cylinder of radius bp_pot except
%   where the spool and its bolt hole sit. Potting density and spool geometry are
%   PLACEHOLDERS (see main script).
in3_to_cc = 16.387064;
mat = p.mat;
m.plug = mat.rho_gcc*in3_to_cc/1000 * pi*(b_plug^2 - (p.d_hole/2)^2)*p.c;     % kg
L_spool    = 2*p.f + p.c;                                            % in
V_flanges  = 2 * pi/4*(p.spool_flange_OD^2 - p.spool_hole_dia^2)*p.spool_flange_t;
V_neck     = pi/4*(p.spool_neck_dia^2 - p.spool_hole_dia^2)*(L_spool - 2*p.spool_flange_t);
V_spool    = V_flanges + V_neck;                                     % solid Al (in^3)
V_spool_in_core = V_spool - pi/4*(p.spool_flange_OD^2 - p.spool_hole_dia^2)*2*p.f;
V_hole_in_core  = pi/4*p.spool_hole_dia^2*p.c;
V_potting  = pi*bp_pot^2*p.c - V_spool_in_core - V_hole_in_core;     % in^3
m.L_spool   = L_spool;
m.V_spool   = V_spool;
m.V_potting = V_potting;
m.spool     = p.rho_al_gcc*in3_to_cc/1000*V_spool;                   % kg
m.potting   = p.rho_potting_gcc*in3_to_cc/1000*V_potting;            % kg
m.potted    = m.spool + m.potting;                                   % kg
end
