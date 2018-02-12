function state = mglgetkeystate(keycode)
%function state = mglgetkeystate(keycode)
%
%	For the keycode, see https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx

state = mdqmex(37,keycode);
