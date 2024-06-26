function Misc=getMuscles4DOFS(Misc)
%   getMuscles4DOFS Selects all the muscles that actuate the DOFS specified by the user
%   Maarten Afschrift, 15 July 2016


% Loop over each DOF in the model
for i=1:length(Misc.DofNames_Input)
    
    % Get the moment arms from the muscle analysis results
    dm_Data_temp=importdata(fullfile(Misc.MuscleAnalysisPath,[Misc.trialName '_MuscleAnalysis_MomentArm_' Misc.DofNames_Input{i} '.sto']));    
    dM=dm_Data_temp.data(1,2:end);    
    dM_store(i,:)=dM;
end

% get the muscles that actuate the selected DOFS (moment arms > 0.001)
MuscleNames=dm_Data_temp.colheaders(2:end);
[~, nm]=size(dM_store);
ct=1;
for i=1:nm
    if any(abs(dM_store(:,i))>0.001)
        Misc.MuscleNames_Input{ct}=MuscleNames{i}; ct=ct+1;
    end    
end

% Default tendon stifness for these muscles
Misc.Atendon=ones(ct-1,1).*35;

% print to screen
disp('MusclesNames Selected automatically:');
disp(Misc.MuscleNames_Input');
end

