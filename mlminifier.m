function mlminifier(dest,source)

if 7~=exist(dest,'dir'), error('The destination folder does not exist.'); end
if ~strcmp(dest(end),filesep), dest = [dest filesep]; end
switch exist(source,'file')
    case 2  % file
        [p,f,e] = fileparts(source);
        p = [p filesep];
        source = {[f e]};
    case 7  % dir
        if filesep~=source(end), source(end+1) = filesep; end
        listing = dir([source '*.m']);
        p = source;
        source = {listing.name}';
        source = source(~strcmp('.',source)&~strcmp('..',source));
    otherwise
        error('Cannot find the source file.');
end

for m=1:length(source)
    [~,f] = fileparts(source{m});
    eval(['clear ' f]);
    code = strtrim(regexp(tree2str(mtree(fileread([p source{m}]))),'[^\n]+\n|[^\n]+$','match'))';
    tokens = regexp(code,'^([^'']*)(''.*'')([^'']*)$','tokens');
    row = cellfun(@isempty,tokens);
    tokens(row) = code(row);
    for n=1:length(tokens)
        if iscell(tokens{n})
            code{n} = [remove_blank(tokens{n}{1}{1}) tokens{n}{1}{2} remove_blank(tokens{n}{1}{3})];
        else
            code{n} = remove_blank(tokens{n});
        end
    end
    
    fid = fopen([dest source{m}],'w');
    for n=1:length(code)
        fprintf(fid,'%s\n',code{n});
    end
    fclose(fid);
end

end

function str = remove_blank(str)
    symbols = {' = ','='; ' \+ ','\+'; ' - ','-'; ' \.\* ','\.\*'; ' \./ ','\./'; ' \.\^ ','\.\^'; ' & ','&'; ' && ','&&'; ' \| ','\|'; ' \|\| ','\|\|'; ...
        '\) \(','\)\('; '\[ ','\['; ' \]','\]'; '\( ','\('; ' \)','\)'; '{ ','{'; ' }','}'; ', ',','; '; ',';'};
    str = regexprep(str,symbols(:,1),symbols(:,2));
end
