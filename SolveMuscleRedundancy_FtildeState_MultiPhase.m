% SolveMuscleRedundancy_FtildeState, version 0.1 (August 2016)
%
% This function solves the muscle redundancy problem in the leg using the
% direct collocation optimal control software GPOPS-II as described in De
% Groote F, Kinney AL, Rao AV, Fregly BJ. Evaluation of direct
% collocation optimal control problem formulations for solving the muscle
% redundancy problem. Annals of Biomedical Engineering (2016).
%
% Authors:  F. De Groote, M. Afschrift, A. Falisse
% Emails:   friedl.degroote@kuleuven.be
%           maarten.afschrift@kuleuven.be
%           antoine.falisse@kuleuven.be
%
% ----------------------------------------------------------------------- %
% This function uses the tendon force Ft as a state (see aforementionned
% publication for more details)
%
% INPUTS:
%           model_path: path to the .osim model
%           IK_path: path to the inverse kinematics results
%           ID_path: path to the inverse dynamics results
%           time: time window
%           OutPath: path to folder where results will be saved
%           Misc: structure of input data (see manual for more details)
%
% OUTPUTS:
%           Time: time window (as used when solving the optimal control
%           problem)
%           MExcitation: muscle excitation
%           MActivation: muscle activation
%           RActivation: activation of the reserve actuators
%           TForce_tilde: normalized tendon force
%           TForce: tendon force
%           lMtilde: normalized muscle fiber length
%           lM: muscle fiber length
%           MuscleNames: names of muscles
%           OptInfo: output of GPOPS-II
%           DatStore: structure with data used for solving the optimal
%           control problem
%
% ----------------------------------------------------------------------- %
%%

function [MExcitation,MActivation,RActivation,MuscleNames,DOFNames,OptInfo,DatStore]=SolveMuscleRedundancy_FtildeState_MultiPhase(model_path,IK_paths,ID_paths,times,OutPath,Misc)

%% ---------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
% PART 0: CHECK INPUTS FOR PHASE INFO ----------------------------------- %
% ----------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
numPhases = length(IK_paths);
if (length(ID_paths) ~= numPhases) || (length(times) ~= numPhases) || (length(ID_paths) ~= length(times))
    error('Input arrays not consistent with a specific number of phases');
end
DatStore = struct();
auxdata = struct();
auxdata.numPhases = numPhases;

%% ---------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
% PART I: INPUTS FOR OPTIMAL CONTROL PROBLEM ---------------------------- %
% ----------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
if ~isfield(Misc, 'study') || isempty(Misc.study)
    Misc.study = 'DeGroote2016/';
end
study = strsplit(Misc.study,'/');
if length(study) == 1
   study{2} = ''; 
end
switch study{1}
    case 'DeGroote2016'
        tag = '';
    case 'ParameterCalibration'
        tag = 'ParamCalMultiPhase';
    otherwise
        tag = '';
end

% ----------------------------------------------------------------------- %
% Check for optional input arguments ------------------------------------ %

% Default low-pass filter:
%   Butterworth order: 6
%   Cutoff frequency: 6Hz
% Inverse Dynamics
if ~isfield(Misc,'f_cutoff_ID') || isempty(Misc.f_cutoff_ID)
    Misc.f_cutoff_ID=6;
end
if ~isfield(Misc,'f_order_ID') || isempty(Misc.f_order_ID)
    Misc.f_order_ID=6;
end
% Muscle-tendon lengths
if ~isfield(Misc,'f_cutoff_lMT') || isempty(Misc.f_cutoff_lMT)
    Misc.f_cutoff_lMT=6;
end
if ~isfield(Misc,'f_order_lMT') || isempty(Misc.f_order_lMT)
    Misc.f_order_lMT=6;
end
% Moment arms
if ~isfield(Misc,'f_cutoff_dM') || isempty(Misc.f_cutoff_dM)
    Misc.f_cutoff_dM=6;
end
if ~isfield(Misc,'f_order_dM') || isempty(Misc.f_order_dM)
    Misc.f_order_dM=6;
end
% Inverse Kinematics
if ~isfield(Misc,'f_cutoff_IK') || isempty(Misc.f_cutoff_IK)
    Misc.f_cutoff_IK=6;
end
if ~isfield(Misc,'f_order_IK') || isempty(Misc.f_order_IK)
    Misc.f_order_IK=6;
end
% Mesh Frequency
if ~isfield(Misc,'Mesh_Frequency') || isempty(Misc.Mesh_Frequency)
    Misc.Mesh_Frequency=100;
end
% Variable tendon stiffness
if ~isfield(Misc, 'tendonStiffnessCoeff') || isempty(Misc.tendonStiffnessCoeff)
    Misc.tendonStiffnessCoeff = 35;
end
% Modify individual tendon stiffnesses
if ~isfield(Misc, 'tendonStiffnessModifiers') || isempty(Misc.tendonStiffnessModifiers)
    Misc.tendonStiffnessModifiers = [];
end
% Modify individual passive muscle strain due to maximum isometric force (e0)
if ~isfield(Misc, 'muscleStrainModifiers') || isempty(Misc.muscleStrainModifiers)
    Misc.muscleStrainModifiers = [];
end
% Modify individual passive muscle force exponential shape factor (kpe)
if ~isfield(Misc, 'muscleShapeFactModifiers') || isempty(Misc.muscleShapeFactModifiers)
    Misc.muscleShapeFactModifiers = [];
end
% Modify individual muscle optimal fiber lengths (lMo)
if ~isfield(Misc, 'optimalFiberLengthModifiers') || isempty(Misc.optimalFiberLengthModifiers)
    Misc.optimalFiberLengthModifiers = [];
end
% Modify individual tendon slack lengths (lTs)
if ~isfield(Misc, 'tendonSlackLengthModifiers') || isempty(Misc.tendonSlackLengthModifiers)
    Misc.tendonSlackLengthModifiers = [];
end
% Modify individual pennation angles @ optimal fiber length (alphao)
if ~isfield(Misc, 'pennationAngleModifiers') || isempty(Misc.pennationAngleModifiers)
    Misc.pennationAngleModifiers = [];
end
% ParameterCalibration: Set of terms to include in the parameter calibration problem
if ~isfield(Misc, 'parameterCalibrationTerms') || isempty(Misc.parameterCalibrationTerms)
    Misc.parameterCalibrationTerms = [];
end
% ParameterCalibration: Filepaths to calibration datasets
if ~isfield(Misc, 'parameterCalibrationData') || isempty(Misc.parameterCalibrationData)
    Misc.parameterCalibrationData = [];
end
% ParameterCalibration: option to pre-calibrate passive muscle properties
if ~isfield(Misc, 'passive_precalibrate') || isempty(Misc.passive_precalibrate)
   Misc.passive_precalibrate = false; 
end

% ----------------------------------------------------------------------- %
% Check that options are being specified correctly -----------------------%
if strcmp(study{1}, 'ParameterCalibration')
   errmsg = 'ParameterCalibration: must specify parameterCalibrationTerms struct';
   assert(~isempty(Misc.parameterCalibrationTerms), errmsg)
   
   % These will be checked later, since we need to do checks on a muscle
   % by muscle basis.
   % Can only optimize muscle parameters from this list. An exception is thrown
   % otherwise.
   acceptable_params = {'optimal_fiber_length', 'tendon_slack_length', 'pennation_angle', 'muscle_strain'};
   % Can only set cost terms from this list. Also, a data file must exist 
   % for each corresponding term. Exceptions are thrown otherwise.
   acceptable_costs = {'emg', 'fiber_length', 'fiber_velocity'};
   
   if ~isempty(length(Misc.parameterCalibrationData.emg))
       errmsg = 'Number of EMG data paths must be consistent with number of phases.';
       assert(length(Misc.parameterCalibrationData.emg) == numPhases, errmsg);
   end
end

% Must specify muscle names ahead of time (for now)
if ~isfield(Misc,'MuscleNames_Input') || isempty(Misc.MuscleNames_Input)
    error('Must specify MuscleNames_Input for multi-phase calibration');
end

for p = 1:numPhases
    
    % ----------------------------------------------------------------------- %
    % Muscle analysis ------------------------------------------------------- %
    Misc.time=times{p};
    MuscleAnalysisPath=fullfile(OutPath,Misc.cycle_ids{p},'MuscleAnalysis');
    if ~exist(MuscleAnalysisPath,'dir')
        mkdir(MuscleAnalysisPath);
        
        disp('MuscleAnalysis Running .....');
        OpenSim_Muscle_Analysis(IK_paths{p},model_path,MuscleAnalysisPath,[times{p}(1) times{p}(end)])
        disp('MuscleAnalysis Finished');
    end
    
    Misc.MuscleAnalysisPath=MuscleAnalysisPath;
    
    % ----------------------------------------------------------------------- %
    % Extract muscle information -------------------------------------------- %
    
    % Get number of degrees of freedom (dofs), muscle-tendon lengths and moment
    % arms for the selected muscles.
    [~,Misc.trialName,~]=fileparts(IK_paths{p});
    [DatStore] = getMuscleInfo_MultiPhase(IK_paths{p},ID_paths{p},Misc,DatStore,p);
    
    % Extract the muscle-tendon properties
    [DatStore(p).params, DatStore(p).lOpt, DatStore(p).L_TendonSlack, DatStore(p).Fiso, ...
        DatStore(p).PennationAngle, DatStore(p).metabolicParams] = ...
        ReadMuscleParameters(model_path, DatStore(p).MuscleNames);
    
    % Check that calibration terms were provided for muscles that exist in
    % the model
    if strcmp(study{1}, 'ParameterCalibration')
        emgCostMuscles = cell(0);
        fiberLengthCostMuscles = cell(0);
        fiberVelocityCostMuscles = cell(0);
        musclesToCalibrate = fieldnames(Misc.parameterCalibrationTerms);
        for m = 1:length(musclesToCalibrate)
            muscle_name = musclesToCalibrate{m};
            errmsg = ['ParameterCalibration: calibration terms provided for ' ...
                muscle_name ' but this muscle does not exist in the model'];
            assert(ismember(muscle_name, DatStore(p).MuscleNames), errmsg);
            
            if isfield(Misc.parameterCalibrationTerms.(musclesToCalibrate{m}), 'params')
                paramsToCalibrate = Misc.parameterCalibrationTerms.(musclesToCalibrate{m}).params;
                errmsg = ['ParameterCalibration: invalid parameter list provided for ' muscle_name '.'];
                assert(all(ismember(paramsToCalibrate, acceptable_params)), errmsg);
            end
            
            if isfield(Misc.parameterCalibrationTerms.(musclesToCalibrate{m}), 'costs')
                calibrationCosts = Misc.parameterCalibrationTerms.(musclesToCalibrate{m}).costs;
                errmsg = ['ParameterCalibration: invalid cost term provided for ' muscle_name '.'];
                assert(all(ismember(calibrationCosts, acceptable_costs)), errmsg);
                errmsg = ['CalibrateParameter: data files not provided for all cost terms for ' muscle_name '.'];
                assert(all(ismember(calibrationCosts, fieldnames(Misc.parameterCalibrationData))), errmsg);
                
                for c = 1:length(calibrationCosts)
                    switch calibrationCosts{c}
                        case 'emg'
                            emgCostMuscles{length(emgCostMuscles)+1} = musclesToCalibrate{m};
                        case 'fiber_length'
                            fiberLengthCostMuscles{length(fiberLengthCostMuscles)+1} = musclesToCalibrate{m};
                        case 'fiber_velocity'
                            fiberVelocityCostMuscles{length(fiberVelocityCostMuscles)+1} = musclesToCalibrate{m};
                    end
                end
            end
        end
    end
    
    % Modify muscle properties
    fprintf('Muscles with modified properties: \n')
    for m = 1:DatStore(p).nMuscles
        muscle_name = DatStore(p).MuscleNames{m};
        if isfield(Misc.tendonStiffnessModifiers, muscle_name)
            DatStore(p).params(6,m) = Misc.tendonStiffnessModifiers.(muscle_name);
            fprintf('--> %s tendon coefficient set to %f \n',muscle_name,DatStore(p).params(6,m))
        else
            DatStore(p).params(6,m) = 1;
        end
        if isfield(Misc.muscleStrainModifiers, muscle_name)
            DatStore(p).params(7,m) = Misc.muscleStrainModifiers.(muscle_name);
            fprintf('--> %s muscle strain set to %f \n',muscle_name,DatStore(p).params(7,m))
        else
            DatStore(p).params(7,m) = 1;
        end
        if isfield(Misc.muscleShapeFactModifiers, muscle_name)
            DatStore(p).params(8,m) = Misc.muscleShapeFactModifiers.(muscle_name);
            fprintf('--> %s muscle shape factor set to %f \n',muscle_name,DatStore(p).params(8,m))
        else
            DatStore(p).params(8,m) = 1;
        end
        if isfield(Misc.optimalFiberLengthModifiers, muscle_name) && ...
                ~ismember('optimal_fiber_length', Misc.parameterCalibrationTerms.(muscle_name).params)
            
            DatStore(p).params(9,m) = Misc.optimalFiberLengthModifiers.(muscle_name);
            fprintf('--> %s muscle optimal fiber length set to %f \n',muscle_name,DatStore(p).params(9,m))
        else
            DatStore(p).params(9,m) = 1;
        end
        if isfield(Misc.tendonSlackLengthModifiers, muscle_name) && ...
                ~ismember('tendon_slack_length', Misc.parameterCalibrationTerms.(muscle_name).params)
            
            DatStore(p).params(10,m) = Misc.tendonSlackLengthModifiers.(muscle_name);
            fprintf('--> %s muscle tendon slack length set to %f \n',muscle_name,DatStore(p).params(10,m))
        else
            DatStore(p).params(10,m) = 1;
        end
        if isfield(Misc.pennationAngleModifiers, muscle_name) && ...
                ~ismember('pennation_angle', Misc.parameterCalibrationTerms.(muscle_name).params)
            
            DatStore(p).params(11,m) = Misc.pennationAngleModifiers.(muscle_name);
            fprintf('--> %s muscle pennation angle set to %f \n',muscle_name,DatStore(p).params(11,m))
        else
            DatStore(p).params(11,m) = 1;
        end
    end
    fprintf('\n')
    
    % ----------------------------------------------------------------------- %
    % Solve the muscle redundancy problem using static optimization --------- %
    
    % The solution of the static optimization is used as initial guess for the
    % dynamic optimization
    DatStore = SolveStaticOptimization_IPOPT_MultiPhase(DatStore, p);

end
%% ---------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
% PART II: OPTIMAL CONTROL PROBLEM FORMULATION -------------------------- %
% ----------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
% Muscles and DOFs are the same for every phase
auxdata.params = DatStore(1).params;  
auxdata.NMuscles = DatStore(1).nMuscles;   % number of muscles
auxdata.Ndof = DatStore(1).nDOF;           % humber of dods
auxdata.metabolicParams = DatStore(1).metabolicParams; % Parameters for calculating metabolic cost
auxdata.MuscleNames = DatStore(1).MuscleNames;
auxdata.DOFNames = DatStore(1).DOFNames;   % names of dofs
tau_act = 0.015;
tau_deact = 0.06;
auxdata.tauAct = tau_act * ones(1,auxdata.NMuscles);       % activation time constant (activation dynamics)
auxdata.tauDeact = tau_deact * ones(1,auxdata.NMuscles);  % deactivation time constant (activation dynamics)
% parameter for determining transition smoothness (activation dynamics)
auxdata.b = 0.1;

for p = 1:numPhases
    % Input arguments
    DatStore(p).formulation = 'Ftilde';
    auxdata.ID(p).p = DatStore(p).T_exp;            % inverse dynamics
    % ADiGator works with 2D: convert 3D arrays to 2D structure (moment arms)
    for i = 1:auxdata.Ndof
        auxdata.MA(i).Joint(p).p(:,:) = DatStore(p).dM(:,i,:);  % moment arms
    end
end
    
if strcmp(study{1}, 'ParameterCalibration')
    auxdata.parameterCalibrationTerms = Misc.parameterCalibrationTerms;
end

% Parameters of active muscle force-velocity characteristic
load ActiveFVParameters.mat
Fvparam(1) = 1.475*ActiveFVParameters(1); Fvparam(2) = 0.25*ActiveFVParameters(2);
Fvparam(3) = ActiveFVParameters(3) + 0.75; Fvparam(4) = ActiveFVParameters(4) - 0.027;
auxdata.Fvparam = Fvparam;

% Parameters of active muscle force-length characteristic
load Faparam.mat
auxdata.Faparam = Faparam;

% Pre-calibration to passive moments from Silder et al. 2007
if strcmp(study{1}, 'ParameterCalibration') && Misc.passive_precalibrate
    calibratedModifiers = PassiveMomentCalibration(model_path, auxdata, DatStore(1), Misc.parameterCalibrationTerms);
    
    % Update parameter structs
    indices = calibratedModifiers.indices;
    auxdata.params(9,indices.lMo) = calibratedModifiers.lMo;
    auxdata.params(10,indices.lTs) = calibratedModifiers.lTs;
    auxdata.params(7,indices.e0) = calibratedModifiers.e0;
end

% Parameters of passive muscle force-length characteristic, and tendon
% characteristic
e0 = 0.6*auxdata.params(7,:);
kpe = 4*auxdata.params(8,:);
t50 = exp(kpe .* (0.2 - 0.10e1) ./ e0);
pp1 = (t50 - 0.10e1); t7 = exp(kpe); pp2 = (t7 - 0.10e1);
auxdata.Fpparam = [pp1;pp2;ones(1,length(pp1))*Misc.tendonStiffnessCoeff];

% Problem bounds
e_min = 0; e_max = 1;           % bounds on muscle excitation
a_min = 0; a_max = 1;           % bounds on muscle activation
F_min = 0; F_max = 5;           % bounds on normalized tendon force
dF_min = -50; dF_max = 50;      % bounds on derivative of normalized tendon force
umin = e_min*ones(1,auxdata.NMuscles);
umax = e_max*ones(1,auxdata.NMuscles);
dFMin = dF_min*ones(1,auxdata.NMuscles);
dFMax = dF_max*ones(1,auxdata.NMuscles);
aTmin = -1*ones(1,auxdata.Ndof);
aTmax = 1*ones(1,auxdata.Ndof);
actMin = a_min*ones(1,auxdata.NMuscles);
actMax = a_max*ones(1,auxdata.NMuscles);
F0min = F_min*ones(1,auxdata.NMuscles);
F0max = F_max*ones(1,auxdata.NMuscles);
Ffmin = F_min*ones(1,auxdata.NMuscles);
Ffmax = F_max*ones(1,auxdata.NMuscles);
FMin = F_min*ones(1,auxdata.NMuscles);
FMax = F_max*ones(1,auxdata.NMuscles);
% pera_lower = -1 * ones(1, auxdata.NMuscles);
% pera_upper = 1 * ones(1, auxdata.NMuscles);
% perFtilde_lower = -1 * ones(1, auxdata.NMuscles);
% perFtilde_upper = 1 * ones(1, auxdata.NMuscles);
HillEquil = zeros(1, auxdata.NMuscles);
ID_bounds = zeros(1, auxdata.Ndof);
for p = 1:numPhases
      
    % Time bounds
    t0 = DatStore(p).time(1); 
    tf = DatStore(p).time(end);
    bounds.phase(p).initialtime.lower = t0; 
    bounds.phase(p).initialtime.upper = t0;
    bounds.phase(p).finaltime.lower = tf; 
    bounds.phase(p).finaltime.upper = tf;
    % Controls bounds
    bounds.phase(p).control.lower = [umin aTmin dFMin]; 
    bounds.phase(p).control.upper = [umax aTmax dFMax];
    if strcmp(study{1}, 'ParameterCalibration')
        musclesToCalibrate = fieldnames(Misc.parameterCalibrationTerms);
        for m = 1:length(musclesToCalibrate)
            muscIdx = find(contains(auxdata.MuscleNames, musclesToCalibrate{m}));
            if isfield(Misc.parameterCalibrationTerms.(musclesToCalibrate{m}), 'bounds')
                muscCalibrationBounds = Misc.parameterCalibrationTerms.(musclesToCalibrate{m}).bounds;
                if isfield(muscCalibrationBounds, 'excitation')
                    bounds.phase(p).control.lower(muscIdx) = muscCalibrationBounds.excitation.lower;
                    bounds.phase(p).control.upper(muscIdx) = muscCalibrationBounds.excitation.upper;
                end
                
            end
        end
    end
    
    % States bounds
    bounds.phase(p).initialstate.lower = [actMin, F0min]; 
    bounds.phase(p).initialstate.upper = [actMax, F0max];
    bounds.phase(p).state.lower = [actMin, FMin]; 
    bounds.phase(p).state.upper = [actMax, FMax];
    bounds.phase(p).finalstate.lower = [actMin, Ffmin]; 
    bounds.phase(p).finalstate.upper = [actMax, Ffmax];
    % Integral bounds
    bounds.phase(p).integral.lower = 0;
    bounds.phase(p).integral.upper = 10000*(tf-t0); 
    
    % Path constraints
    bounds.phase(p).path.lower = [ID_bounds,HillEquil]; 
    bounds.phase(p).path.upper = [ID_bounds,HillEquil];
    
    % Eventgroup
    % Impose mild periodicity
%     bounds.eventgroup.lower = [pera_lower perFtilde_lower]; 
%     bounds.eventgroup.upper = [pera_upper perFtilde_upper];

end

% Parameter bounds
if strcmp(study{1}, 'ParameterCalibration')
    parameterCalibrationIndices = struct();
    index = 1;
    params_lower = [];
    params_upper = [];
    params_guess = [];
    musclesToCalibrate = fieldnames(Misc.parameterCalibrationTerms);
    for m = 1:length(musclesToCalibrate)
        muscIdx = find(contains(auxdata.MuscleNames, musclesToCalibrate{m}));
        paramsToCalibrate = Misc.parameterCalibrationTerms.(musclesToCalibrate{m}).params;
        for pp = 1:length(paramsToCalibrate)
            if strcmp(paramsToCalibrate{pp}, 'muscle_strain')
                continue;
            elseif strcmp(paramsToCalibrate{pp}, 'optimal_fiber_length')
                preCalVal = auxdata.params(9,muscIdx);               
                params_lower = [params_lower 0.75];
                params_upper = [params_upper 1.25];
            elseif strcmp(paramsToCalibrate{pp}, 'tendon_slack_length')
                preCalVal = auxdata.params(10,muscIdx);
                params_lower = [params_lower 0.75];
                params_upper = [params_upper 1.25];
            end
            params_guess = [params_guess preCalVal];
            
            parameterCalibrationIndices.(musclesToCalibrate{m}).(paramsToCalibrate{pp}) = index;
            index = index + 1;
        end
    end
    
    % Append additional scaling parameters for muscles without EMG data
    muscsWithEMG = {'med_gas_r','glut_max2_r','rect_fem_r','semimem_r','soleus_r','tib_ant_r','vas_int_r'};
    for m = 1:length(emgCostMuscles)
        if ~any(strcmp(muscsWithEMG, emgCostMuscles{m}))
            parameterCalibrationIndices.(emgCostMuscles{m}).emgScale = 1;
        end
    end
    
    bounds.parameter.lower = params_lower;
    bounds.parameter.upper = params_upper;
    guess.parameter = params_guess;
    auxdata.parameterCalibrationIndices = parameterCalibrationIndices;
end

% Initial guess
for p = 1:numPhases
    guess.phase(p).time = DatStore(p).time;
    guess.phase(p).control = [DatStore(p).SoAct DatStore(p).SoRAct./150 zeros(length(DatStore(p).time),auxdata.NMuscles)];
    % guess.phase(p).state =  [DatStore(p).SoAct 0.2*ones(N,auxdata.NMuscles)];
    guess.phase(p).state =  [DatStore(p).SoAct DatStore(p).SoAct];
    guess.phase(p).integral = 0;
end

% Spline structures
for p = 1:numPhases
    DatStore(p).T_exo = zeros(length(DatStore(p).time),auxdata.Ndof);
    for dof = 1:auxdata.Ndof
        for m = 1:auxdata.NMuscles
            auxdata.JointMASpline(dof).Muscle(p).p(m) = spline(DatStore(p).time, auxdata.MA(dof).Joint(p).p(:,m));
        end
        auxdata.JointIDSpline(p).p(dof) = spline(DatStore(p).time,DatStore(p).T_exp(:,dof));
        auxdata.JointEXOSpline(p).p(dof) = spline(DatStore(p).time,DatStore(p).T_exo(:,dof));
        auxdata.JointIKSpline(p).p(dof) = spline(DatStore(p).time,DatStore(p).q_exp(:,dof));
    end
    
    for m = 1:auxdata.NMuscles
        auxdata.LMTSpline(p).p(m) = spline(DatStore(p).time,DatStore(p).LMT(:,m));
    end
    
    % Spline calibration cost data
    if strcmp(study{1}, 'ParameterCalibration')
        % Create muscle name map to access correct data columns
        keySet = {'med_gas_r','glut_max2_r','rect_fem_r','semimem_r','soleus_r','tib_ant_r','vas_int_r','psoas_r'};
        valueSet = {'gasmed_r','glmax2_r','recfem_r','semimem_r','soleus_r','tibant_r','vasmed_r','recfem_r'};
        musc_map = containers.Map(keySet, valueSet);
        
        % Spline EMG data
        interpEMGToSpline = zeros(length(DatStore(p).time), auxdata.NMuscles);
        if ~isempty(emgCostMuscles)
            emg = tdfread(Misc.parameterCalibrationData.emg{p});
            startTime = DatStore(p).time(1);
            endTime = DatStore(p).time(end);
            [~, startIdx] = min(abs(emg.time - startTime));
            [~, endIdx] = min(abs(emg.time - endTime));
            % pad the time vector so we cover the OCP time range
            for i = 1:3
                if (startIdx ~= 1) 
                    startIdx = startIdx-1;
                end
            end
            for i = 1:3
                if (endIdx ~= length(emg.time)) 
                    endIdx = endIdx+1;
                end
            end
%             startTime = emg.time(startIdx);
%             endTime = emg.time(endIdx);
            for m = 1:length(emgCostMuscles)
                muscleEMG = emg.(musc_map(emgCostMuscles{m}))(startIdx:endIdx);
                emgPeak = max(muscleEMG);
                scale = emgPeak / (emgPeak - 0.05);
                emgTime = emg.time(startIdx:endIdx);
                muscleEMGrescaled = scale * (muscleEMG - 0.05);
%                 delayTime = linspace(startTime, endTime, 1000*(endTime-startTime));
%                 emgDelayInterp = interp1(emg.time(startIdx:endIdx), muscleEMG(startIdx:endIdx), delayTime);
%                 emgDelayInterpShifted = circshift(emgDelayInterp, 40);
%                 emgMuscInterp = interp1(delayTime, emgDelayInterpShifted, DatStore(p).time);
                emgMuscInterp = interp1(emgTime, muscleEMGrescaled, DatStore(p).time);
                muscIdx = find(contains(auxdata.MuscleNames, emgCostMuscles{m}));
                interpEMGToSpline(:,muscIdx) = emgMuscInterp;
            end
        end
        
        % Spline fiber length data
        interpFLToSpline = zeros(length(DatStore(p).time), auxdata.NMuscles);
        if ~isempty(fiberLengthCostMuscles)
            fiber_length = tdfread(Misc.parameterCalibrationData.fiber_length);
            startTime = DatStore(p).time(1);
            endTime = DatStore(p).time(end);
            [~, startIdx] = min(abs(fiber_length.time - startTime));
            [~, endIdx] = min(abs(fiber_length.time - endTime));
            for m = 1:length(fiberLengthCostMuscles)
                muscleFL = fiber_length.(musc_map(fiberLengthCostMuscles{m}));
                flMuscInterp = interp1(fiber_length.time(startIdx:endIdx), muscleFL(startIdx:endIdx), DatStore(p).time);
                muscIdx = find(contains(auxdata.MuscleNames, fiberLengthCostMuscles{m}));
                interpFLToSpline(:,muscIdx) = flMuscInterp;
            end
        end
        
        % Spline fiber velocity data
        interpFVToSpline = zeros(length(DatStore(p).time), auxdata.NMuscles);
        if ~isempty(fiberVelocityCostMuscles)
            fiber_velocity = tdfread(Misc.parameterCalibrationData.fiber_velocity);
            startTime = DatStore(p).time(1);
            endTime = DatStore(p).time(end);
            [~, startIdx] = min(abs(fiber_velocity.time - startTime));
            [~, endIdx] = min(abs(fiber_velocity.time - endTime));
            for m = 1:length(fiberVelocityCostMuscles)
                muscleFV = fiber_velocity.(musc_map(fiberVelocityCostMuscles{m}));
                fvMuscInterp = interp1(fiber_velocity.time(startIdx:endIdx), muscleFV(startIdx:endIdx), DatStore(p).time);
                muscIdx = find(contains(auxdata.MuscleNames, fiberVelocityCostMuscles{m}));
                interpFVToSpline(:,muscIdx) = fvMuscInterp;
            end
        end
        
        for m = 1:DatStore(p).nMuscles
            auxdata.EMGSpline(p).p(m) = spline(DatStore(p).time, interpEMGToSpline(:,m));
            auxdata.FLSpline(p).p(m) = spline(DatStore(p).time, interpFLToSpline(:,m));
            auxdata.FVSpline(p).p(m) = spline(DatStore(p).time, interpFVToSpline(:,m));
        end
        
    end
end

% GPOPS setup        
setup.name = 'DynamicOptimization_FtildeState';
setup.auxdata = auxdata;
setup.bounds = bounds;
setup.guess = guess;
setup.nlp.solver = 'ipopt';
setup.nlp.ipoptoptions.linear_solver = 'ma57';
setup.derivatives.derivativelevel = 'first';
setup.nlp.ipoptoptions.tolerance = 1e-2;
setup.nlp.ipoptoptions.maxiterations = 10000;
setup.derivatives.supplier = 'sparseCD';
setup.scales.method = 'none';
setup.mesh.method = 'hp-PattersonRao';
setup.mesh.tolerance = 1e-2;
setup.mesh.maxiterations = 5;
setup.mesh.colpointsmin = 5;
setup.mesh.colpointsmax = 10;
setup.method = 'RPM-integration';
setup.displaylevel = 2;
for p = 1:numPhases
    t0 = DatStore(p).time(1); 
    tf = DatStore(p).time(end);
    NMeshIntervals(p).p = round((tf-t0)*Misc.Mesh_Frequency);
    setup.mesh.phase(p).colpoints = 3*ones(1,NMeshIntervals(p).p);
    setup.mesh.phase(p).fraction = (1/(NMeshIntervals(p).p))*ones(1,NMeshIntervals(p).p);
end
setup.functions.continuous = str2func(['continous_Ftilde' tag]);
setup.functions.endpoint = str2func(['endpoint_Ftilde' tag]);
    
% ADiGator setup
global splinestruct
input.auxdata = auxdata;
for p = 1:numPhases
    tdummy = guess.phase(p).time;
    splinestruct(p).p = SplineInputData_MultiPhase(tdummy,input,p);
    splinenames = fieldnames(splinestruct(p).p);
    for Scount = 1:length(splinenames)
        secdim = size(splinestruct(p).p.(splinenames{Scount}),2);
        splinestructad.(splinenames{Scount}) = adigatorCreateAuxInput([Inf,secdim]);
        splinestruct(p).p.(splinenames{Scount}) = zeros(0,secdim);
    end
    setup.auxdata.splinestruct(p).p = splinestructad;
end
% adigatorGenFiles4gpops2(setup)

setup.functions.continuous = str2func(['Wrap4continous_Ftilde' tag]);
% setup.adigatorgrd.continuous = str2func(['continous_Ftilde' tag 'GrdWrap']);
% setup.adigatorgrd.endpoint   = str2func(['endpoint_Ftilde' tag 'ADiGatorGrd']);
% setup.adigatorhes.continuous = str2func(['continous_Ftilde' tag 'HesWrap']);
% setup.adigatorhes.endpoint   = str2func(['endpoint_Ftilde' tag 'ADiGatorHes']);

%% ---------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %
% PART III: SOLVE OPTIMAL CONTROL PROBLEM ------------------------------- %
% ----------------------------------------------------------------------- %
% ----------------------------------------------------------------------- %

output = gpops2(setup);

for p = 1:numPhases
    res=output.result.solution.phase(p);
%     Time=res.time;
    MActivation.(Misc.cycle_ids{p}) = res.state(:,1:auxdata.NMuscles);
%     TForcetilde.(Misc.cycle_ids{p}) = res.state(:,auxdata.NMuscles+1:auxdata.NMuscles*2);
%     TForce.(Misc.cycle_ids{p}) = TForcetilde.*(ones(size(Time))*DatStore.Fiso);
%     dTForcetilde.(Misc.cycle_ids{p}) = 10*res.control(:,auxdata.NMuscles+auxdata.Ndof+1:auxdata.NMuscles+auxdata.Ndof+auxdata.NMuscles);
    MExcitation.(Misc.cycle_ids{p}) = res.control(:,1:auxdata.NMuscles);
    RActivation.(Misc.cycle_ids{p}) = res.control(:,auxdata.NMuscles+1:auxdata.NMuscles+auxdata.Ndof);
    
end
MuscleNames = auxdata.MuscleNames;
DOFNames = auxdata.DOFNames;
OptInfo=output;

% Save calibrated parameter modifications
if strcmp(study{1}, 'ParameterCalibration')
    musclesToCalibrate = fieldnames(Misc.parameterCalibrationTerms);
    for m = 1:length(musclesToCalibrate)
        muscIdx = find(contains(auxdata.MuscleNames, musclesToCalibrate{m}));
        paramsToCalibrate = Misc.parameterCalibrationTerms.(musclesToCalibrate{m}).params;
        for p = 1:length(paramsToCalibrate)
            if strcmp(paramsToCalibrate{p}, 'optimal_fiber_length')
                idx = parameterCalibrationIndices.(musclesToCalibrate{m}).(paramsToCalibrate{p});
                OptInfo.paramCal.(musclesToCalibrate{m}).(paramsToCalibrate{p}) = output.result.solution.parameter(idx);
            elseif strcmp(paramsToCalibrate{p}, 'tendon_slack_length')
                idx = parameterCalibrationIndices.(musclesToCalibrate{m}).(paramsToCalibrate{p});
                OptInfo.paramCal.(musclesToCalibrate{m}).(paramsToCalibrate{p}) = output.result.solution.parameter(idx);
            elseif strcmp(paramsToCalibrate{p}, 'muscle_strain')
                OptInfo.paramCal.(musclesToCalibrate{m}).(paramsToCalibrate{p}) = auxdata.params(7, muscIdx);
            end
        end
    end
end

% % Retrieve splined muscle length and velocity curves
% for m = 1:auxdata.NMuscles
%     [LMT(:,m),VMT(:,m),~] = SplineEval_ppuval(auxdata.LMTSpline(m),Time,1);
% end
% 
% % Get muscle data from DeGroote muscle model
% MuscleData = DeGroote2016Muscle_FtildeState(MActivation, TForcetilde, ...
%     dTForcetilde, LMT, VMT, auxdata.params, auxdata.Fvparam, auxdata.Fpparam, ... 
%     auxdata.Faparam);

end
