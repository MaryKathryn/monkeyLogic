function rect = mglgetadapterrect(device)
%rect = mglgetadapterrect(device)
%   rect - [left top right bottom], Windows screen coordinates
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

ndevice = mglgetadaptercount;
if device<1 || ndevice<device, error('The specified adapter does not exist. Use 1-%d.',ndevice); end

rect = mdqmex(2,device-1);
