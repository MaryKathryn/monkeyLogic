function outputTable = tableFromTxt(txtFileName)

outputTable = readtable(txtFileName);
outputTable.Properties.VariableNames = {'Condition'    'Info'     'Frequency'    'Block'     'Timing_File'     'TaskObject1'      'TaskObject2'     'TaskObject3'};

end 