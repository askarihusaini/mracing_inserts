function s = ternary_str(cond, a, b)
%TERNARY_STR  Return a if cond is true, else b (used inside fprintf calls).
if cond
    s = a;
else
    s = b;
end
end
