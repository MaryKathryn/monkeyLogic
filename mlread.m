function [data,MLConfig,TrialRecord,filename] = mlread(filename)
%MLREAD returns trial and configuration data from bhv2 and h5.
%
%   [DATA, CONFIG] = MLREAD(FILENAME)
%
%   Mar 7, 2017             Written by Jaewon Hwang (jaewon.hwang@nih.gov or jaewon.hwang@hotmail.com)

if ~exist('filename','var') || 2~=exist(filename,'file')
    [n,p] = uigetfile({'*.bhv2;*.h5;*.bhv','MonkeyLogic Datafile (*.bhv2;*.h5;*.bhv)'});
    if isnumeric(n), error('File not selected'); end
    filename = [p n];
end
[~,~,e] = fileparts(filename);
switch lower(e)
    case '.bhv2', fid = mlbhv2(filename,'r');
    case '.h5', fid = mlhdf5(filename,'r');
    case '.mat', fid = mlmat(filename);
    case '.bhv', data = bhv_read(filename); return;
    otherwise, error('Unknown file format');
end

MLConfig = [];
TrialRecord = [];
data = fid.read_trial();
if 1<nargout, MLConfig = fid.read('MLConfig'); end
if 2<nargout, TrialRecord = fid.read('TrialRecord'); end
close(fid);

end
