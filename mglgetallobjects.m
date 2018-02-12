function [id,type,status] = mglgetallobjects()
%[id,type] = mglgetallobjects()
%
%	This function returns the IDs of all the objects added and their
%	types ('BITMAP','MOVIE',etc.).
%
%   May 4, 2016     Written by Jaewon Hwang (jaewon.hwang@hotmail.com)

[id,type,status] = mdqmex(14);
