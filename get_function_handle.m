function h = get_function_handle(funcpath)

if ~exist('funcpath','var') || 2~=exist(funcpath,'file'), h = []; return, end

[p,n] = fileparts(funcpath);
if 7==exist(p,'dir'), cwd = pwd; cd(p); end
eval(['clear ' n]);
h = str2func(n);
if exist('cwd','var'), cd(cwd); end

% try
%     h(); %#ok<NOEFF>
% catch err
%     if strcmp(err.identifier,'MATLAB:UndefinedFunction')
%         error('Can''t find the function, ''%s''.',n);
%     end
% end
