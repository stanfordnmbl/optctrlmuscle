function phaseout = continous_Ftilde_vA_Met(input)

% Get input data
NMuscles        = input.auxdata.NMuscles;
Ndof            = input.auxdata.Ndof;
tauAct          = input.auxdata.tauAct;
tauDeact        = input.auxdata.tauDeact;
params          = input.auxdata.params;
metabolicParams = input.auxdata.metabolicParams;
splinestruct    = input.auxdata.splinestruct;
numColPoints    = size(input.phase.state,1);

% Get controls
vA   = 100*input.phase.control(:,1:NMuscles);
aT  = input.phase.control(:,NMuscles+1:NMuscles+Ndof);
dFtilde  = 10*input.phase.control(:,NMuscles+Ndof+1:end);

% Get states
a       = input.phase.state(:,1:NMuscles);
Ftilde = input.phase.state(:,NMuscles+1:end);

% PATH CONSTRAINTS
% Activation dynamics - De Groote et al. (2009)
act1 = vA + a./(ones(size(a,1),1)*tauDeact);
act2 = vA + a./(ones(size(a,1),1)*tauAct);

% Hill-equilibrium constraint
[Hilldiff,F,Fce,Fiso,vMtilde,lMtilde] = DeGroote2016Muscle_FtildeState(a,Ftilde,dFtilde,splinestruct.LMT,splinestruct.VMT,params,input.auxdata.Fvparam,input.auxdata.Fpparam,input.auxdata.Faparam);

% Moments constraint
Topt = 150;
Tdiff = zeros(numColPoints,Ndof);
for dof = 1:Ndof
    T_exp=splinestruct.ID(:,dof);
    index_sel=(dof-1)*(NMuscles)+1:(dof-1)*(NMuscles)+NMuscles;
    T_sim=sum(F.*splinestruct.MA(:,index_sel),2) + Topt*aT(:,dof);
    Tdiff(:,dof) =  (T_exp-T_sim);
end

phaseout.path = [Tdiff Hilldiff act1 act2];

% DYNAMIC CONSTRAINTS
% Activation dynamics is implicit
% Contraction dynamics is implicit
phaseout.dynamics = [vA dFtilde];

% OBJECTIVE FUNCTION
Edot = zeros(numColPoints, NMuscles);
for m = 1:NMuscles
    Lce = lMtilde(:,m)*params(2,m);
    Vce = vMtilde(:,m)*params(5,m);
    u = computeExcitationRaasch(a(:,m), vA(:,m), tauDeact(m), tauAct(m));
    paramStruct = [metabolicParams(1,m), metabolicParams(2,m), ...
                   metabolicParams(3,m), metabolicParams(4,m), ...
                   metabolicParams(5,m)];
    Edot(:,m) = calcUmbergerCost2010(Lce, Vce, Fce(:,m), Fiso(:,m), u, a(:,m), paramStruct);
end

w_aT = 1000;
w_a = 0.05;
w_vA = 0.05;
w_Edot = 1/(input.auxdata.model_mass*9.81*1.25);
phaseout.integrand = w_Edot*sum(Edot, 2) + w_aT.*sum(aT.^2,2)+ w_a*sum(a.^2,2) + w_vA*sum((vA/100).^2,2);
 




