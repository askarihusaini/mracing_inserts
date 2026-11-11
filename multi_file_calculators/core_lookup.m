function core = core_lookup(lib, name)
%CORE_LOOKUP Return the entry of core library LIB whose .name matches NAME.
%   Errors with the list of valid names if NAME is not found.
idx = find(strcmp({lib.name}, name), 1);
if isempty(idx)
    error('Unknown core "%s". Valid names: %s', name, strjoin({lib.name}, ', '));
end
core = lib(idx);
end
