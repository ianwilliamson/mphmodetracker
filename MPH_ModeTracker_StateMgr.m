classdef MPH_ModeTracker_StateMgr < handle
    properties (SetAccess = public)
        current;
        last;
        next;
        retriesMax=8;
        mode=MPH_ModeTracker_SweepMode.Param;
    end
    properties (SetAccess = private)
        retries=0;
        retriesGlobal=0;
    end
    methods
        function SM = MPH_ModeTracker_StateMgr()
            SM.next=MPH_ModeTracker_State.Start;
            SM.current=MPH_ModeTracker_State.Start;
        end
        function doStateTransition(SM)
            SM.last=SM.current;
            SM.current=SM.next;
            SM.next=MPH_ModeTracker_State.UNKNOWN;
        end
        function incRetries(SM)
            SM.retries=SM.retries+1;
            SM.retriesGlobal=SM.retriesGlobal+1;
        end
        function resetRetries(SM)
            SM.retries=0;
        end
        function tf=exceedeMaxRetries(SM)
            tf = (SM.retries>SM.retriesMax);
        end
    end 
end