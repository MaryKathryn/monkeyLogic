function [status,priority] = mglkeepsystemawake(state)
%current_state = mglkeepsystemawake(state)
%	state - on(1), off(2), or [] for getting the current state
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if 0 < nargin
    [status,priority] = mdqmex(36,logical(state));
else
    [status,priority] = mdqmex(36);
end
