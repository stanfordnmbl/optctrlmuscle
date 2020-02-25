function output = endpoint_FtildeExoTopology_Met(input)

q = input.phase.integral;
output.objective = q;

NMuscles = input.auxdata.NMuscles;

% Initial and end states
a_end = input.phase.finalstate(1:NMuscles);
Ftilde_end = input.phase.finalstate(NMuscles+1:2*NMuscles);
aD_end = input.phase.finalstate(2*NMuscles+1:end);

a_init = input.phase.initialstate(1:NMuscles);
Ftilde_init = input.phase.initialstate(NMuscles+1:2*NMuscles);
aD_init = input.phase.initialstate(2*NMuscles+1:end);

% Constraints - mild periodicity
pera = a_end - a_init;
perFtilde = Ftilde_end - Ftilde_init;
peraD = aD_end - aD_init;

output.eventgroup.event = [pera perFtilde peraD];
