function [ExoTorques_Act, MomentArms_Act, ExoTorques_Pass, MomentArms_Pass, Fexo_pass, s, Lexo, IK] = calcExoTorques_Ftilde_vAExoTopology_ActPass(OptInfo,DatStore)

time = OptInfo.result.solution.phase.time;
numColPoints = length(time);
auxdata = OptInfo.result.setup.auxdata;
Ndof = auxdata.Ndof;

% Get active device control and passive slack variable
aD = OptInfo.result.solution.phase.control(:,end-1);
s  = OptInfo.result.solution.phase.control(:,end);

% Get moment arms
parameter = OptInfo.result.solution.parameter;
exoMomentArms = zeros(numColPoints,6);
if auxdata.active.hip
    exoMomentArms(:,1) = parameter(:,auxdata.active.hip);
end
if auxdata.active.knee
    exoMomentArms(:,2) = parameter(:,auxdata.active.knee);
end
if auxdata.active.ankle
    exoMomentArms(:,3) = parameter(:,auxdata.active.ankle);
end
if auxdata.passive.hip
    exoMomentArms(:,4) = parameter(:,auxdata.passive.hip);
end
if auxdata.passive.knee
    exoMomentArms(:,5) = parameter(:,auxdata.passive.knee);
end
if auxdata.passive.ankle
    exoMomentArms(:,6) = parameter(:,auxdata.passive.ankle);
end
MomentArms_Act = exoMomentArms(1,1:3);
MomentArms_Pass = exoMomentArms(1,4:6);

% Slack length of passive elastic device
exoSlackLength = parameter(:,end);
slackLength = exoSlackLength(1);

% Exosuit path length
Lexo = zeros(numColPoints,1);
IK = interp1(DatStore.time, (pi/180)*DatStore.q_exp, time);
for dof = 1:Ndof
    if auxdata.passive.hip && (dof==auxdata.hip_DOF)
        Lexo = Lexo + -exoMomentArms(:,4).*IK(:,auxdata.hip_DOF);
    end
    if auxdata.passive.knee && (dof==auxdata.knee_DOF)
        Lexo = Lexo + -exoMomentArms(:,5).*IK(:,auxdata.knee_DOF)*auxdata.kneeAngleSign;
    end
    if auxdata.passive.ankle && (dof==auxdata.ankle_DOF)
        Lexo = Lexo + -exoMomentArms(:,6).*IK(:,auxdata.ankle_DOF);
    end
end

% Exosuit torques
% Active device
Texo_act_hip = auxdata.Fmax_act*aD.*exoMomentArms(:,1);
Texo_act_knee = auxdata.Fmax_act*aD.*exoMomentArms(:,2);
Texo_act_ankle = auxdata.Fmax_act*aD.*exoMomentArms(:,3);

% Calculate passive force based on normalized exo path length
k = auxdata.passiveStiffness;
Fexo_pass = k*(Lexo - exoSlackLength) + s;
Texo_pass_hip = Fexo_pass.*exoMomentArms(:,4);
Texo_pass_knee = Fexo_pass.*exoMomentArms(:,5);
Texo_pass_ankle = Fexo_pass.*exoMomentArms(:,6);

ExoTorques_Act = zeros(length(time), Ndof);
ExoTorques_Pass = zeros(length(time), Ndof);
for dof = 1:Ndof
    if dof==auxdata.hip_DOF
        ExoTorques_Act(:,dof) = Texo_act_hip;
        ExoTorques_Pass(:,dof) = Texo_pass_hip;
    end
    if dof==auxdata.knee_DOF
        ExoTorques_Act(:,dof) = Texo_act_knee;
        ExoTorques_Pass(:,dof) = Texo_pass_knee;
    end
    if dof==auxdata.ankle_DOF
        ExoTorques_Act(:,dof) = Texo_act_ankle;
        ExoTorques_Pass(:,dof) = Texo_pass_ankle;
    end
end

end