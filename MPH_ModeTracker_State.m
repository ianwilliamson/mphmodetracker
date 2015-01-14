classdef MPH_ModeTracker_State
    enumeration
        Start
        Setup
        NewParam
        StepParam
        RunParam
        StepFreq
        RunFreq
        Compute
        Validate
        Extract
        Retry
        Exit
        UNKNOWN
    end
end