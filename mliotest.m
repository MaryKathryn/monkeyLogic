function [C,timingfile,userdefined_trialholder] = mliotest(MLConfig,TrialRecord)

C = [];
timingfile = 'mliotest_timingfile.m';
userdefined_trialholder = '';

TrialRecord.Pause = false;     % skip the pause menu
TrialRecord.TestTrial = true;  % do not create datafile
