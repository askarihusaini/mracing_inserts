function pot = potting_lookup(name, bead_factor)
%POTTING_LOOKUP  Potting-compound properties for the potted spool, selected by name.
%   name         'INF-114' or 'LAM-151-HT'
%   bead_factor  glass-bead density factor applied to the NEAT resin density
%                ([] = library default). The 0.6 default is the MR26 sheet's
%                assumption for INF-114; it is copied to LAM-151-HT as an
%                ASSUMPTION (same bead loading), NOT measured.
%
%   Fields: name, rho_neat_gcc, bead_factor, rho_gcc (value used for mass),
%           comp_yield_psi, comp_note, Tg_onset_F, Tg_note, mix, source, verified.
%
%   What is and is not known:
%   * LAM-151-HT numbers are from the Pro-Set LAM-151-HT / LAM-251-HT technical data
%     sheet (Rev 6, Mar 2025), measured on NEAT resin (no beads). The glass-bead-filled
%     strength and density are not in the datasheet.
%   * The datasheet cures are 200F x 12 h, 250F x 8 h and 140F x 2 h + 302F x 4 h.
%     There is no data for a 350 F co-cure, which is what the monocoque sees.
%   * INF-114: only the neat density (MR26 sheet) and the 14 ksi "potting compressive
%     strength" from the MR25 Core Data sheet are known here. Its source is not documented.
if nargin < 2, bead_factor = []; end

switch name
    case 'INF-114'
        pot.name           = 'INF-114';
        pot.rho_neat_gcc   = 0.01868*1000/16.387064;       % MR26 sheet, neat epoxy (g/cc)
        pot.bead_default   = 0.6;                           % MR26 sheet: x0.6 for glass beads
        pot.rho_default    = 0.01121*1000/16.387064;       % MR26 sheet value, kept literal
        pot.comp_yield_psi = 14000;                         % MR25 "Core Data" sheet, potting comp strength
        pot.comp_note      = 'MR25 Core Data sheet (source of the 14 ksi not documented)';
        pot.Tg_onset_F     = NaN;
        pot.Tg_note        = 'Tg not recorded in the repo';
        pot.mix            = 'not recorded';
        pot.source         = 'MR26 / MR25 Chassis Inserts sheets';
    case 'LAM-151-HT'
        pot.name           = 'LAM-151-HT';
        pot.rho_neat_gcc   = 1.13;                          % datasheet, cured, 72 F (9.45 lb/gal)
        pot.bead_default   = 0.6;                           % ASSUMED, copied from INF-114
        pot.rho_default    = pot.rho_neat_gcc*pot.bead_default;
        pot.comp_yield_psi = 16300;                         % ASTM D695, 140F x 2 h + 302F x 4 h cure, NEAT
        pot.comp_note      = 'datasheet, neat resin, 140F/2h + 302F/4h cure (16.6-16.7 ksi for the 200F and 250F cures); bead-filled value unknown';
        pot.Tg_onset_F     = 328;                           % DMA onset storage modulus, 140F/2h + 302F/4h (E1640)
        pot.Tg_note        = ['datasheet post-cure 302F: DMA onset storage 328F (164C), tan-delta peak 357F (181C), HDT 324F (162C); ' ...
                              'DSC ultimate Tg 346F (175C). Datasheet has no data for a 350F cure.'];
        pot.mix            = 'resin LAM-151-HT : hardener LAM-251-HT = 100:27 by weight (3.70:1), 100:33.3 by volume';
        pot.source         = 'Pro-Set LAM-151-HT/LAM-251-HT technical data, Rev 6 / Mar 2025';
    otherwise
        error('Unknown potting_material "%s". Valid: INF-114, LAM-151-HT.', name);
end

pot.verified = false;                 % neat datasheet values only; filled properties not measured
if isempty(bead_factor)
    pot.bead_factor = pot.bead_default;
    pot.rho_gcc     = pot.rho_default;
else
    pot.bead_factor = bead_factor;
    pot.rho_gcc     = pot.rho_neat_gcc*bead_factor;
end
end
