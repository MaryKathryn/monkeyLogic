classdef mlmat < handle
    properties (SetAccess = protected)
        filename
    end
    properties (Access = protected)
        append
    end
    
    methods
        function obj = mlmat(filename)
            if exist('filename','var'), obj.open(filename); end
        end
        function open(obj,filename)
            obj.filename = filename;
            obj.append = 2==exist(filename,'file');
        end            
        function close(~), end
        
        function write(obj,val,name)
            if isobject(obj)
                field = fieldnames(val);
                for m=1:length(field)
                    a.(name).(field{m}) = val.(field{m}); %#ok<*STRNU>
                end
            else
                a.(name) = val;
            end
            if obj.append
                save(obj.filename,'-struct','a','-append','-nocompression');
            else
                save(obj.filename,'-struct','a','-v7.3','-nocompression');
            end
        end
        function val = read(obj,name)
            a = load(obj.filename,name);
            val = a.(name);
        end
        function val = read_trial(obj)
            a = load(obj.filename,'-regexp','^Trial\d+$');
            field = fieldnames(a);
            for m=1:length(field)
                val(m) = a.(sprintf('Trial%d',m)); %#ok<AGROW>
            end
        end
        function val = who(obj)
            val = who('-file',obj.filename);
       end
    end
end
