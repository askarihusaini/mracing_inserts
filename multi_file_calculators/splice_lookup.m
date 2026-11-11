function sp = splice_lookup(name)
%SPLICE_LOOKUP  3M Scotch-Weld AF 3074 FST structural core splice film, by version.
%   name  'AF3074-30mil' or 'AF3074-50mil'
%
%   Source: 3M Scotch-Weld AF 3074 FST Structural Core Splice Film, PRELIMINARY Technical Data
%   Sheet, issue date June 2025. The sheet says its values are typical, not for specification.
%
%   IMPORTANT LIMITS OF THE DATA
%   * Tube shear strength is measured on solid 5052-O aluminum tubes (prEN 2667-2, 12.5 mm
%     high, film foamed in the annulus), for cure cycle A only (60 min at 257 F). It is NOT a
%     honeycomb core-splice strength. On a honeycomb wall only the foil edges (solidity =
%     core density / Al density, about 3.6% at 6.1 pcf) touch the film unless the foamed film
%     climbs the cell walls, so the useful allowable is between a foil-edge-only lower bound and
%     the solid-Al upper bound. A push-out coupon test is needed to settle it.
%   * No strength data at a 350 F cure (the datasheet cures are 257 F and 320 F). Expansion is
%     lower for the hotter cycle (about 125% vs 225%).
%   * Expansion is read as (expanded - initial)/initial; this is consistent with the sheet's
%     cured density < 0.50 g/cc for the 50 mil film (1.26 g/cc / 3.25 = 0.39 g/cc).
switch name
    case 'AF3074-30mil'
        sp.thickness_in = 0.030;   sp.areal_kgm2 = 0.900;
    case 'AF3074-50mil'
        sp.thickness_in = 0.050;   sp.areal_kgm2 = 1.600;
    otherwise
        error('Unknown splice film "%s". Valid: AF3074-30mil, AF3074-50mil.', name);
end
sp.name = name;
sp.source = '3M AF 3074 FST preliminary TDS, June 2025';
sp.expansion_A_pct = 225;          % cure A: 60 min at 257 F, 5-7 F/min, atmospheric (free expansion)
sp.expansion_B_pct = 125;          % cure B: 30 min at 320 F, hot-in / hot-out
sp.density_cured_A_gcc = 0.50;     % upper bound ("< 0.50 g/cm^3"), free expansion
sp.cure_min_F = 248;               % suggested minimum cure temperature
sp.cure_range_F = [250 350];       % "250 F to 350 F curable"
sp.cure_onset_F = [230 239];       % begins to cure
sp.service_F = [-67 275];
sp.tube_shear_F   = [-67 73 176 275];          % F
sp.tube_shear_psi = [1883 1883 1738 1014];     % psi, cure cycle A, solid 5052-O Al tubes
sp.tube_shear_73F_psi = 1883;
sp.slump_in = [0.02 0.01];         % vertical slump, cures A / B
sp.shelf = '12 months below 0 F; 1 month at room temperature; 15 days shop life';
sp.verified = false;               % typical preliminary values only
end
