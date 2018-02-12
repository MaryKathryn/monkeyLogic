function [width, height, refreshrate] = mglgetadapterdisplaymode(device)
%[width, height, refreshrate] = mglgetadapterdisplaymode(device)
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('device','var'), error('The graphic adapter number must be provided.'); end
    
ndevice = mglgetadaptercount;
if device<1 || ndevice<device, error('The specified adapter does not exist. Use 1-%d.',ndevice); end

[width, height, refreshrate] = mdqmex(1,device-1);
