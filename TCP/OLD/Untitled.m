%Timing test between ML and UE
Data= mlread('C:\Users\Rancor\Documents\MATLAB\Add-Ons\Apps\MonkeyLogic-master\task\UE4_Test\180130_testing_UE_Test(1).bhv2');

P_ST = Data(2).UEData.P_SampleTime;
U_QT = Data(2).UEData.UE_QueryTime;

P_ST = cellfun(@(x) str2double(x), P_ST);
 
U_QT = cell2mat(cellfun(@(x) datevec(x), U_QT, 'uni', 0));

for k=1:size(U_QT,1)
    
   tempU_QT(k,1) = etime(U_QT(k,:), U_QT(1,:));
    
end

tempP_ST = P_ST - P_ST(1);