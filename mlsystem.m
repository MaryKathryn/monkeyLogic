classdef mlsystem < handle
    properties (SetAccess = protected)
        OperatingSystem
        ComputerName
        UserName
        NumberOfProcessors
        ProcessorArchitecture
        NumberOfScreenDevices
    end
    
    methods
        function obj = mlsystem()
            obj.OperatingSystem = getenv('OS');
            obj.ComputerName = getenv('COMPUTERNAME');
            obj.UserName = getenv('USERNAME');
            obj.NumberOfProcessors = getenv('NUMBER_OF_PROCESSORS');
            obj.ProcessorArchitecture = getenv('PROCESSOR_ARCHITECTURE');
            if isempty(obj.ProcessorArchitecture), obj.ProcessorArchitecture = getenv('CPU'); end
            try
                obj.NumberOfScreenDevices = mglgetadaptercount;
            catch
                obj.NumberOfScreenDevices = size(get(0,'MonitorPositions'),1);
            end
        end
    end
end
