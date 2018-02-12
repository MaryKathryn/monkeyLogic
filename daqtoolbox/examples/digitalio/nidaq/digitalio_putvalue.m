dio = digitalio('nidaq','Dev1');
addline(dio,0:7,'Out');

tic; putvalue(dio,[1 1 1 1 1 1 1 1]);
fprintf('putvalue: %s s\n',toc);

putvalue(dio,255);  % equivalent
