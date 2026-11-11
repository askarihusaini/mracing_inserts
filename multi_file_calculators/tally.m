function [vals, cnt] = tally(vals, cnt, v, n)
%TALLY  Add n to the count of value v (keeps vals sorted ascending).
i = find(abs(vals - v) < 1e-9, 1);
if isempty(i)
    vals(end+1) = v;
    cnt(end+1)  = n;
    [vals, idx] = sort(vals);
    cnt = cnt(idx);
else
    cnt(i) = cnt(i) + n;
end
end
