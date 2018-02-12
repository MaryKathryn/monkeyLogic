function [inVBlank,ScanLine] = mglgetrasterstatus(screen)
%[inVBlank,ScanLine] = mglgetrasterstatus()
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

if ~exist('screen','var'), screen = 1; end

[inVBlank,ScanLine] = mdqmex(25,screen);
