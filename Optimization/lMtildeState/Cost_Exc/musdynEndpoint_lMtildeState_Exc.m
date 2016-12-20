function output = musdynEndpoint_lMtildeState_Exc(input)

q = input.phase.integral;
output.objective = q;

NMuscles = input.auxdata.NMuscles;

% Initial and end states
a_end = input.phase.finalstate(1:NMuscles);
lMtilde_end = input.phase.finalstate(NMuscles+1:end);

a_init = input.phase.initialstate(1:NMuscles);
lMtilde_init = input.phase.initialstate(NMuscles+1:end);

% Constraints - mild periodicity
pera = a_end - a_init;
perlMtilde = lMtilde_end - lMtilde_init;

output.eventgroup.event = [pera perlMtilde];
