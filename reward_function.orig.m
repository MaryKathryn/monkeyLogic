function num_reward = reward_function(Duration, varargin)
num_reward = 0;

% Define user variables below. To change their values, call goodmonkey()
% like the following.
%
%   goodmonkey(DURATION, 'VARIABLE_NAME1',NEW_VALUE1, 'VARIABLE_NAME2',NEW_VALUE2);
%
% Unless the variables are defined as persistent, all changes are temporary.
persistent Reward Channel Polarity RewardOn RewardOff
persistent NumReward PauseTime TriggerVal
JuiceLine = 1;  % default juice
NonBlocking = 0;

% Define what should be done to turn on and off your reward device in
% reward_on() and reward_off(), respectively. You can use your own
% variables you define above. The customization of reward_on() and
% reward_off() is not supported in the non-blocking mode.
    function reward_on()
        switch class(Reward)
            case 'analogoutput', putsample(Reward,RewardOn);
            case 'digitalio', putvalue(Reward,RewardOn);
        end
    end
    function reward_off()
        switch class(Reward)
            case 'analogoutput', putsample(Reward,RewardOff);
            case 'digitalio', putvalue(Reward,RewardOff);
        end
    end

%
% The rest of the function below hardly needs modification.
%
if ischar(Duration), varargin = [Duration varargin]; Duration = 0; end
if Duration < 0
    DAQ = varargin{1};
    MLConfig = varargin{2};
    Reward = DAQ.Reward;
    if isempty(Reward), return, end
    Polarity = 1==MLConfig.RewardPolarity;
    r = MLConfig.RewardFuncArgs;
    NumReward = r.NumReward;
    PauseTime = r.PauseTime;
    TriggerVal = r.TriggerVal;
    eval(r.Custom);
    switch class(Reward)
        case 'analogoutput'
            Channel = strcmp(Reward.Channel.ChannelName,'Reward');
            RewardOn = zeros(1,length(Reward.Channel));
            RewardOff = RewardOn;
        case 'digitalio'
            nLine = length(Reward.Line);
            RewardOff = logical(true(1,nLine) .* ~Polarity);
    end
    return;
end

ML_WarmingUp = false;
code = [];
if ~isempty(varargin)
    nargs = length(varargin);
    if mod(nargs,2), error('goodmonkey() requires all arguments beyond the first to come in parameter/value pairs'); end
    for m = 1:2:nargs
        val = varargin{m+1};
        switch lower(varargin{m})
            case 'numreward', NumReward = val;
            case 'pausetime', PauseTime = val;
            case 'eventmarker', code = val;
            case 'juiceline', JuiceLine = val;
            case 'nonblocking', NonBlocking = val;
            case 'triggerval', TriggerVal = val;
            case 'duration', Duration = val;
            case 'eval', eval(val);
            otherwise, eval(sprintf('%s=%f;',varargin{m},val));
        end
    end
end
switch class(Reward)
    case 'analogoutput'
        RewardOn(Channel) = TriggerVal * Polarity;
        RewardOff(Channel) = TriggerVal * ~Polarity;
    case 'digitalio'
        RewardOn = RewardOff;
        RewardOn(JuiceLine) = Polarity;
    otherwise
        error('Unknown reward object!!!');
end
switch length(code)
    case 0, code = NaN(1,NumReward);
    case 1, code = repmat(code,1,NumReward);
    otherwise, code(end+1:NumReward) = code(end);
end

switch NonBlocking
    case 0
        for m = 1:NumReward
            if ML_WarmingUp
                % To use analog reward with stimulation, do not call reward_off().
                mdqmex(102,Duration);
                break
            else
                reward_on();
                mdqmex(99,Duration,code(m));
                reward_off();
                mdqmex(100);
                if m < NumReward, mdqmex(102,PauseTime); end
            end
        end
    case {1,2}
        mdqmex(106,NumReward,Duration,code,PauseTime,NonBlocking,RewardOn,RewardOff);
    otherwise
        error('Unknown NonBlocking Mode!!!');
end
num_reward = NumReward;

end
