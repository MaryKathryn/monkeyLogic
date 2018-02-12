% Parallel digital I/O is implemented with InpOut32
% (http://www.highrez.co.uk/downloads/inpout32/) which works fine in both
% 32-bit and 64-bit Windows. You need to run MATLAB as administrator first
% time you run this example so that the parallel port driver can be
% installed.

dio = digitalio('parallel','LPT1');
addline(dio,0:7,'Out');

tic; putvalue(dio,[1 1 1 1 1 1 1 1]);
fprintf('putvalue: %s s\n',toc);

putvalue(dio,255);  % equivalent
