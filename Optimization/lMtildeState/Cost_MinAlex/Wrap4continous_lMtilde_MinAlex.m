function phaseout = Wrap4continous_lMtilde_MinAlex(input)

persistent splinestruct

if isempty(splinestruct)|| size(splinestruct.MA,1) ~= length(input.phase.time) 
    splinestruct = SplineInputData(input.phase.time,input);
end

input.auxdata.splinestruct = splinestruct;

phaseout = continous_lMtilde_MinAlex(input);