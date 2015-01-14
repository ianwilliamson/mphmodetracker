classdef MPH_ModeTracker_COMSOLSolverMgr < handle
    properties (SetAccess = private)
        SOLVER_TAGS    = {'sol1','sol2'};
        DATCOMSOLSlvrMgrET_TAGS   = {'dset1','dset2'};
        PLOTGROUP_TAGS = {'pg1','pg2'};
        state=1;
        num_solvers=2;
    end
    methods
        function COMSOLSlvrMgr=MPH_ModeTracker_COMSOLSolverMgr(num)
            COMSOLSlvrMgr.state=1;
            COMSOLSlvrMgr.num_solvers=num;
        end
        function detectSolvers(COMSOLSlvrMgr,m)
            try
                if m.sol( COMSOLSlvrMgr.SOLVER_TAGS{2} ).isActive == 1
                    COMSOLSlvrMgr.num_solvers=2;
                else
                    COMSOLSlvrMgr.num_solvers=1;
                end
            catch
                COMSOLSlvrMgr.num_solvers=1;
            end
        end
        function step(COMSOLSlvrMgr)
            COMSOLSlvrMgr.state = mod(COMSOLSlvrMgr.state,COMSOLSlvrMgr.num_solvers)+1;
        end
        function val=current(COMSOLSlvrMgr)
            val = COMSOLSlvrMgr.state;
        end
        function val=last(COMSOLSlvrMgr)
            val = mod(COMSOLSlvrMgr.state,COMSOLSlvrMgr.num_solvers)+1;
        end
        function tag=solver_tag(COMSOLSlvrMgr)
            tag = COMSOLSlvrMgr.SOLVER_TAGS{ COMSOLSlvrMgr.current };
        end
        function tag=dataset_tag(COMSOLSlvrMgr)
            tag = COMSOLSlvrMgr.DATCOMSOLSlvrMgrET_TAGS{ COMSOLSlvrMgr.current };
        end
        function tag=plotgroup_tag(COMSOLSlvrMgr)
            tag = COMSOLSlvrMgr.PLOTGROUP_TAGS{ COMSOLSlvrMgr.current };
        end
    end
end