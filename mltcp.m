%Handles setting up the TCP connection and keeping it active across trials.
%Also sends the EXIT command to UDK upon exiting ML. 

classdef mltcp < handle
    properties (SetAccess = public)
       
        temp_UE_Data = {};
        
        UE_Position = {};
        UE_Rotation = {};
        UE_Time = {};
        UE_State = {};
        UE_QueryTime = {};
        P_SampleTime = {};
        P_Error = {};
        P_ErrorTime = {};
        
    end
    
    properties (SetAccess = protected)
        %TCP handlers for python tunnel
        pyObj = [];
        IP_Address = '123.123.123.12'
        IP_Port = uint16(3000)
        TCP_BufferSize = uint16(2^16)
        
        %Out Terminator: adding these chars at the end of send message ====
        %TCP_OutTerminator = '' %UE4
        TCP_OutTerminator = [char(13) char(10)] %UE3
        %==================================================================
        
        %In Terminator: waiting for these chars to stop acquiring =========
        %TCP_InTerminator = [char(13) char(10)] %UE4
        TCP_InTerminator = ' END OF TRANSMISSION' %UE3
        %==================================================================
        TCP_TimeOut = 1.00
        TCP_Status = false
        
    end
    properties (Hidden)
       
    end
    
    methods
        %Creator function =================================================
        function obj = mltcp(MLConfig)
            if exist('MLConfig','var') && isa(MLConfig,'mlconfig')
                create(obj,MLConfig);
            else
                %do nothing
            end
        end
        %==================================================================
        
        %Destructor function===============================================
        function delete(obj)
            %send message to Unreal engine to close
            obj.Quit();
            
            destroy(obj);
        end
        
        function destroy(obj)
            
            try
                if ~isempty(obj.pyObj)
                    %Close TCP socket
                    obj.pyObj.Close();
                    obj.pyObj = [];
                end
            catch
                % do nothing
            end
        end
        %==================================================================
        
        %create function; we will initialize the TCP connection here =======
        function obj = create(obj,MLConfig)

            %deletes connection if already have one
            if ~isempty(obj.pyObj)
                destroy(obj);
            end
            
            %makes sure the TCP_Tunnel is in the python search path
            pyPath = py.sys.path;
            mlPath = [MLConfig.MLPath.BaseDirectory 'TCP' filesep];
            
            if count(pyPath,mlPath) == 0
                insert(pyPath,int32(0),mlPath);
            end
            
            %make sure we are running the latest version
            module = py.importlib.import_module('ML_MatlabTcpTunnel');
            py.importlib.reload(module);
            clear module
            
            %Creates python object
            obj.pyObj = py.ML_MatlabTcpTunnel.ML_MatlabTcpTunnel(obj.IP_Address,...
                obj.IP_Port,...
                obj.TCP_BufferSize, ...
                obj.TCP_InTerminator,...
                obj.TCP_OutTerminator,...
                obj.TCP_TimeOut);
    
            %try connection
            try
                obj.TCP_Status = obj.pyObj.Connect();
                if (obj.TCP_Status)%good
                    MLConfig.TCP = obj;
                else %abort
                    error('Could not initialize TCP Connection');
                end
            catch err
                %catches error message and display it
                fprintf('<<< MonkeyLogic >>> %s\n',err.message);
                rethrow(err);
            end
            
        end
        %==================================================================
        
        %Gets called only by the end_trial function in trialholder_v2
       function getPythonBuffers(obj)
           if obj.TCP_Status
               %returns the data from all Python Buffers as lists in the
               %following order:
               %    Position
               %    Rotation
               %    Player State
               %    Unreal Sample Time
               %    Unreal Query Time (i.e. time of execution of PostRender()
               %    Python Sample Time (from start of trial; i.e. 0)
               %    Python Error Buffer (e.g. timeouts)
               %    Python Error Times

               %Get all buffers: < 1ms
               tempBuffers = cell(obj.pyObj.ReturnAllBuffers());
               
               %Separates tempBuffers into appropriate variables 
               obj.UE_Position = strsplit(strrep(strrep(char(tempBuffers{1}), '[''', ''), ''']', ''), ''', ''')';
               obj.UE_Rotation = strsplit(strrep(strrep(char(tempBuffers{2}), '[''', ''), ''']', ''), ''', ''')';
               obj.UE_State = strsplit(strrep(strrep(char(tempBuffers{3}), '[''', ''), ''']', ''), ''', ''')';
               obj.UE_Time = strsplit(strrep(strrep(char(tempBuffers{4}), '[''', ''), ''']', ''), ''', ''')';
               obj.UE_QueryTime = strsplit(strrep(strrep(char(tempBuffers{5}), '[''', ''), ''']', ''), ''', ''')';
               obj.P_SampleTime = strsplit(strrep(strrep(char(tempBuffers{6}), '[', ''), ']', ''), ',')';
               obj.P_Error = strsplit(strrep(strrep(char(tempBuffers{7}), '[''', ''), ''']', ''), ''', ''')';
               obj.P_ErrorTime = strsplit(strrep(strrep(char(tempBuffers{8}), '[', ''), ']', ''), ',')';
               
               %clears temp_UE_Data
               obj.temp_UE_Data = [];
           end
        end
        
        function out = getTCPStatus(obj)
            out = obj.TCP_Status;
        end
        
        %UE Functions =====================================================
        function GetState(obj)
            if obj.TCP_Status
                obj.temp_UE_Data = [obj.temp_UE_Data; {char(obj.pyObj.ReturnSingleData('Sta'))}];
            else
                %do nothing
            end
        end
                
        function Quit(obj)
            if obj.TCP_Status
                %sends EXIT Command to UE
                obj.SendMessage('QUIT');
            end
        end
        
        function out = OnBlack(obj)
            if obj.TCP_Status
                out = obj.SendMessage('ONBLACK');
                if out
                    obj.temp_UE_Data = {};
                end
            end
        end
        
        function out = TrackerMessage(obj, Message)
            if obj.TCP_Status
                out = obj.SendMessage(Message);
                if out
                    obj.temp_UE_Data = {};
                end
            end
        end
        
        function out = EndTrial(obj)
            if obj.TCP_Status
                out = obj.SendMessage('ENDTRIAL');
                obj.temp_UE_Data = {};
            end
        end
        
        function [out] = SetFixAndSpeed(obj, Fix, Speed)
             out = obj.SendMessage(['SPEEDANDFIXATIONPOINT {bFixPoint ' Fix '} ' ...
                                                '{fPercentSpeed ' Speed '}']);
        end
        
        function [out] = MapChange(obj, Map)
            if obj.TCP_Status
                out = obj.pyObj.MapChange(Map);
                %Connection breaks on map change, need a quick re-connect,
                %handled by the python object
            end
        end  
        
        function [out] = StartTrial(obj)
           if obj.TCP_Status
               out = obj.SendMessage('STARTTRIAL');
           end
        end
        %Send Data to Tracker =============================================
        function sample = getLatestSample(obj)
            sample = obj.temp_UE_Data;
        end
        
        %TCP I/O ==========================================================
        function out = AcquireMessage(obj)
            if obj.TCP_Status
                out = char(obj.pyObj.ReceiveMessage()); 
            end
        end
        
        function out = SendMessage(obj,Message)
            if obj.TCP_Status
                %Sends Message and output 1
                out = obj.pyObj.SendMessage(Message);
            end
        end
        
        function init_timer(obj)
           obj.pyObj.Init_Timer();
        end
        %==================================================================
    end
    
    %local functions
    methods (Access = protected)
           
        
    end
end
