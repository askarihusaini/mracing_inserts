function L = hardpoint_loads(p)
%HARDPOINT_LOADS  Design loads (SF applied) for one hardpoint.
%   p.load_mode        'bracket' : link force + bracket FBD (type A / B)
%                      'direct'  : p.direct_P/Q/M entered per insert (unfactored)
%   p.load_convention  'whole_bracket' (method 1, current default): P per insert,
%                         but Q, M and friction are WHOLE-bracket values applied to
%                         each insert. Conservative, internally inconsistent with P.
%                      'per_insert': Q and M divided by inserts_per_bracket, and
%                         friction taken per bolt.
%   Outputs per insert: P, Q, M, Q_bearing.  Outputs for a puck that holds
%   p.inserts_per_puck inserts: Ppk, Qpk, Mpk.
n = p.inserts_per_bracket;

switch lower(p.load_mode)
    case 'bracket'
        F   = p.link_force_N * 0.224809;               % N -> lb
        ang = p.angle_deg*pi/180;
        Fn  = F*cos(ang);                              % normal to panel, whole bracket
        Fs  = F*sin(ang);                              % in-plane, whole bracket
        switch upper(p.bracket_type)
            case 'B'   % inserts share the normal load; moment carried at base
                P_ins = Fn/n;
                M_ins = Fs*p.y;
            case 'A'   % moment resolved into a bolt-load couple (sheet FBD)
                if n ~= 2
                    error('Bracket type A (bolt couple) is only defined for 2 inserts.');
                end
                P_ins = Fn/2 + Fs*p.y/p.a;             % worst (outside) bolt
                M_ins = 0;
            otherwise
                error('bracket_type must be ''A'' or ''B''');
        end
        max_friction = n*p.bolt_preload*p.mu*p.use_friction*p.preload_retention;  % whole bracket
        switch lower(p.load_convention)
            case 'whole_bracket'
                P  = p.SF*P_ins;
                Q  = max(p.SF*Fs - max_friction, 0);
                M  = p.SF*M_ins;
                Qb = p.SF*Fs;                          % bearing: no friction credit
            case 'per_insert'
                P  = p.SF*P_ins;
                Q  = max(p.SF*Fs - max_friction, 0)/n;
                M  = p.SF*M_ins/n;
                Qb = p.SF*Fs/n;
            otherwise
                error('load_convention must be ''whole_bracket'' or ''per_insert''');
        end
        % Bracket resultants (what a puck sharing all the inserts sees)
        P_tot = p.SF*Fn;
        Q_tot = max(p.SF*Fs - max_friction, 0);
        M_tot = p.SF*Fs*p.y;
        L.F = F;  L.Fn = Fn;  L.Fs = Fs;
        if p.inserts_per_puck == 1
            Ppk = P;  Qpk = Q;  Mpk = M;
        elseif p.inserts_per_puck == n
            Ppk = P_tot;  Qpk = Q_tot;  Mpk = M_tot;
        else
            error('inserts_per_puck must be 1 or equal to inserts_per_bracket.');
        end
    case 'direct'
        max_friction = 0;                              % no friction credit in direct mode
        P  = p.SF*p.direct_P;
        Q  = p.SF*p.direct_Q;
        M  = p.SF*p.direct_M;
        Qb = Q;
        if P <= 0
            error('Direct mode needs direct_P > 0 (the punch-out and bond checks divide by P).');
        end
        % Approximation: a puck holding k inserts carries k times the per-insert loads
        Ppk = p.inserts_per_puck*P;  Qpk = p.inserts_per_puck*Q;  Mpk = p.inserts_per_puck*M;
        L.F = NaN;  L.Fn = NaN;  L.Fs = NaN;
    otherwise
        error('load_mode must be ''bracket'' or ''direct''');
end

L.P = P;  L.Q = Q;  L.M = M;  L.Q_bearing = Qb;
L.max_friction = max_friction;
L.Ppk = Ppk;  L.Qpk = Qpk;  L.Mpk = Mpk;
L.Q_before_friction = L.Fs*p.SF;                       % NaN in direct mode
end
