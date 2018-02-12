function [C,timingfile,userdefined_trialholder] = mltimetest(MLConfig,TrialRecord)

TrialRecord.Pause = false;     % skip the pause menu
TrialRecord.TestTrial = true;  % do not create datafile

C = {'pic(benchmarkpic.jpg,0,0)','mov(initializing.avi,0,0)'};
timingfile = 'mltimetest_timingfile.m';
userdefined_trialholder = '';
