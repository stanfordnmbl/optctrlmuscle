function heatRates = calcUmbergerCost2010Smooth(Lce,Vce,F,Fiso,u,a, params)
%-------------------------------------------------------------------------------
% Smooth cost function based on the metabolics probe of Umberger et al. (2003)
% and Umberger (2010), and the MATLAB probe implementation by Tom Uchida.
%
% USAGE
%   heatRates = calcUmbergerCost2010Smooth(Lce,Vce,F,Fiso,u,a,params);
%
% INPUTS
%      Lce: length of the contractile element [m]
%      Vce: velocity of the contractile element [m/s] (shortening is negative)
%        F: force generated by the contractile element [N]
%     Fiso: the ratio (relative to Fmax) of force that would be generated
%           isometrically at a=1 (e.g., Fiso=1 at Lceopt)
%        u: excitation in [0,1]
%        a: activation in [0,1]
%   params: structure array containing muscle parameters (see PARAMETERS)
%
% PARAMETERS 
%                      rFT: ratio of fast-twitch muscle fibers [0,1]
%                   Lceopt: optimal fiber length [non-neg]
%  VceMax_LceoptsPerSecond: max contractile velocity [Lceopt/s]      
%               muscleMass: muscle mass [non-neg]
%           scalingFactorS: aerobic vs. anaerobic scaling factor [non-neg]
%    
% OUTPUTS [W/kg_muscle_mass]
%   Activation heat rate
%   Maintenance heat rate
%   Shortening and lengthening heat rate
%   Mechanical work rate
%   Total rate of energy liberation
%
% Original probe implementation: Tom Uchida
% Modifications for smooth cost function: Nick Bianco
%-------------------------------------------------------------------------------

%% Activation and maintenance heat rate.
hdotAM = 128*params.rFT + 25;
hdotActivation = hdotAM*0.4;
hdotMaintenance = hdotAM*0.6;

%% Shortening and lengthening heat rate (shortening is negative).
VtildeCE = Vce/params.Lceopt;
VtildeCEmax = params.VceMax_LceoptsPerSecond;
VtildeCEmax_FT = VtildeCEmax;

% TODO: how to handle cases where rFT ~= 0.05?
fiberRatioFactor = logisticFuncLessThan(params.rFT, 0.05) + ...
                 0.4 * logisticFuncGreaterThan(params.rFT, 0.05);
VtildeCEmax_ST = VtildeCEmax * fiberRatioFactor;


alphaS_ST = (4*25) / VtildeCEmax_ST;
alphaS_FT = (1*153) / VtildeCEmax_FT;

% Shortening. ST fibers continue to liberate energy at their maximum rate if
% the whole muscle shortens faster than the maximum velocity of ST fibers.
% Note: "the first term on the right-hand side of Eq. (11)" is not a precise
% statement. This calculation was clarified with Brian Umberger over email.
STterm = min(-alphaS_ST*VtildeCE, alphaS_ST*VtildeCEmax_ST);
hdotShorten = STterm*(1-params.rFT) - alphaS_FT*VtildeCE*params.rFT;

% Lengthening.
alphaL = 0.3*alphaS_ST;
hdotLengthen = alphaL*VtildeCE;

hdotShortenLengthen = hdotShorten * logisticFuncLessThan(VtildeCE, 0) + ...
                      hdotLengthen * logisticFuncGreaterThan(VtildeCE, 0);


%% Mechanical work rate (wdot>0 when shortening).
wdot = max(-F*Vce/params.muscleMass, 0);

%% Scaling.
% Account for effect of length and activation on hdotAM and hdotSL,
% and dependence of total heat rate on metabolic working conditions 
%(aerobic vs.anaerobic).

% --> length dependence
lengthDependenceFactor = logisticFuncLessThan(Lce, params.Lceopt) + ...
                         Fiso * logisticFuncGreaterThan(Lce, params.Lceopt);
hdotMaintenance = lengthDependenceFactor*hdotMaintenance;
hdotShortenLengthen = lengthDependenceFactor*hdotShortenLengthen;


% --> submaximal activation: rapid rise (slow decay) of heat production at
%                            beginning (end) of excitation
scalingFactorA = ((u+a)/2) * logisticFuncLessThan(u, a) + ...
                 u * logisticFuncGreaterThan(u, a);
scalingFactorA_AM = scalingFactorA^0.6;
scalingFactorA_S = scalingFactorA^2.0;

actHdotFactor = scalingFactorA_S * logisticFuncLessThan(VtildeCE, 0) + ...
                scalingFactorA * logisticFuncGreaterThan(VtildeCE, 0);
hdotShortenLengthen = hdotShortenLengthen * actHdotFactor;
hdotActivation = hdotActivation * scalingFactorA_AM;
hdotMaintenance = hdotMaintenance * scalingFactorA_AM;

% --> aerobic vs. anaerobic
hdotActivation = hdotActivation * params.scalingFactorS;
hdotMaintenance = hdotMaintenance * params.scalingFactorS;
hdotShortenLengthen = hdotShortenLengthen * params.scalingFactorS;

% Total heat rate cannot fall below 1.0 W/kg.
totalHeat = hdotActivation + hdotMaintenance + hdotShortenLengthen;
hdotOverride = 1.0 - hdotMaintenance - hdotShortenLengthen;
hdotActivation = hdotOverride * logisticFuncLessThan(totalHeat, 1.0) + ...
                hdotActivation * logisticFuncGreaterThan(totalHeat, 1.0);

%% Total energy rate.
heatRates = [hdotActivation, hdotMaintenance, hdotShortenLengthen, wdot, ...
	hdotActivation + hdotMaintenance + hdotShortenLengthen + wdot];

end

function [left] = logisticFuncLessThan(value, transPt)

left = 1 ./ (1 + exp(100 * (value - transPt)));

end

function [right] = logisticFuncGreaterThan(value, transPt)

right = 1 ./ (1 + exp(100 * (transPt - value)));

end
