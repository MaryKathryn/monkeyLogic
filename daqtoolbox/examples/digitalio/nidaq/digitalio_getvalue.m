dio = digitalio('nidaq','Dev1');
addline(dio,0:7,'In');

tic; val = getvalue(dio)     % binary
fprintf('getvalue: %s s\n',toc);

binvec2dec(val)              % decimal
