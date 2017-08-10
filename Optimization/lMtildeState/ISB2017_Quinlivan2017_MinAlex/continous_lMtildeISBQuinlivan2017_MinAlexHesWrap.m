function phaseout = continous_lMtildeISBQuinlivan2017_MinAlexHesWrap(input)

persistent splinestruct

if isempty(splinestruct)|| size(splinestruct.MA,1) ~= length(input.phase.time.f)    
    splinestruct = SplineInputData(input.phase.time.f,input);
end

input.auxdata.splinestruct = splinestruct;

phaseout = continous_lMtildeISBQuinlivan2017_MinAlexADiGatorHes(input);