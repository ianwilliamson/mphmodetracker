classdef MPH_ModeTracker_SweepMode
    enumeration
        Param
        Freq
    end
    methods
        function tf = isParamTrackActive(obj)
            tf = (obj == MPH_ModeTracker_SweepMode.Param);
        end
        function tf = isFreqTrackActive(obj)
            tf = (obj == MPH_ModeTracker_SweepMode.Freq);
        end
    end
end