function rows = read_hardpoint_csv(fname)
%READ_HARDPOINT_CSV  Read a hardpoint table (header row + one hardpoint per line).
%   Returns a struct array. Cells that parse as numbers become doubles, everything
%   else stays a string. Plain comma separation, no quoted commas. Lines starting
%   with '#' are ignored. Written without readtable so it runs in MATLAB and Octave.
fid = fopen(fname, 'r');
if fid < 0
    error('Cannot open hardpoint table "%s".', fname);
end
cleanup = onCleanup(@() fclose(fid));
hdr = {};
rows = struct([]);
n = 0;
while true
    ln = fgetl(fid);
    if ~ischar(ln), break; end
    ln = strtrim(ln);
    if isempty(ln) || ln(1) == '#', continue; end
    cells = strtrim(strsplit(ln, ','));
    if isempty(hdr)
        hdr = cells;
        continue
    end
    n = n + 1;
    for j = 1:numel(hdr)
        if j <= numel(cells), v = cells{j}; else, v = ''; end
        d = str2double(v);
        if ~isnan(d), v = d; end
        rows(n).(hdr{j}) = v;
    end
end
end
