%% Example
% add main folder and subfolder to matlab path (installation)
filepath=which('Collins2015.m');
[DirCurrent,~,~]=fileparts(filepath);
[DirISB2017,~]=fileparts(DirCurrent);
[DirExamples,~]=fileparts(DirISB2017);
[MainDir,~]=fileparts(DirExamples);
addpath(genpath(MainDir));

% Needed Input Arguments
if isempty(getenv('OPENSIM_HOME'))
    error('You must define the OPENSIM_HOME environment variable.');
end
Datapath = fullfile(getenv('OPENSIM_HOME'), 'Models', 'Gait10dof18musc', ...
    'OutputReference');
IK_path=fullfile(Datapath,'IK','subject01_walk_IK.mot');
ID_path=fullfile(Datapath,'ID','inversedynamics.sto');
%ID_path=[]; % compute ID from the external loads
model_path=fullfile(Datapath,'subject01.osim');
time=[0.7 1.4];     % Part of the right stance phase
OutPath=fullfile(DirCurrent,'Results');

Misc.DofNames_Input={'ankle_angle_r','knee_angle_r','hip_flexion_r'};
Misc.Loads_path=fullfile(Datapath,'ExperimentalData','subject01_walk_grf.xml');

% Optional Input Arguments
Misc.costfun = 'Exc_Act';
Misc.study = 'ISB2017/Collins2015';

%% Solve the problem
[Time,MExcitation,MActivation,RActivation,TForcetilde,TForce,lMtilde,lM,MuscleNames,OptInfo,DatStore] = SolveMuscleRedundancy_lMtildeState(model_path,IK_path,ID_path,time,OutPath,Misc);
ExoTorques = getExoTorques(OptInfo,DatStore,Misc);
filename='Collins2015_MRS_solution_opt.mat';
savepath=fullfile(DirCurrent,filename);
save(savepath,'Time','MExcitation','MActivation','RActivation','TForcetilde', ...
        'TForce','lMtilde','lM','MuscleNames','OptInfo','DatStore','ExoTorques');
    
for i = 0.1:0.1:0.3
    Misc.ankle_clutched_spring_stiffness = i;
    [Time,MExcitation,MActivation,RActivation,TForcetilde,TForce,lMtilde,lM,MuscleNames,OptInfo,DatStore] = SolveMuscleRedundancy_lMtildeState(model_path,IK_path,ID_path,time,OutPath,Misc);
    ExoTorques = getExoTorques(OptInfo,DatStore,Misc);
    filename=strcat('Collins2015_MRS_solution_spring_stiffness_',num2str(i),'.mat');
    savepath=fullfile(DirCurrent,filename);
    save(savepath,'Time','MExcitation','MActivation','RActivation','TForcetilde', ...
        'TForce','lMtilde','lM','MuscleNames','OptInfo','DatStore','ExoTorques');
end

function ExoTorques = getExoTorques(OptInfo,DatStore,Misc)

q_exp = DatStore.q_exp;
maxSpringStiff = 400; % N-m/rad.
normSpringStiff = OptInfo.result.solution.parameter(1);
springRestAngle = OptInfo.result.solution.parameter(2);
for dof = 1:length(Misc.DofNames_Input)  
    if contains(Misc.DofNames_Input{dof},'ankle_angle')
        ankleAngle = -(q_exp(:,dof) - springRestAngle);
        ExoTorques.ankle_angle = maxSpringStiff * normSpringStiff .* ankleAngle;
    end   
end

end