function output = MPH_ModeTracker_Run(varargin)
% output = MPH_ModeTracker_Run(varargin)
%
% Parameters:
% sweep (struct) specifies comsol parameter combinations that will be swept
% freqs (array)
%
% Parameter-value pairs:
% 'mph', string of full path to comsol model file
% 'lambda_search', complex number specifying starting lambda_search. taken from model if not specified
% 'savedat',['']
% 'savedir',['./data/']
% 'mode_rules', [{'lambda', @(x) x>1; 'lambda', @(x) abs(imag(x))<=1.01*abs(real(x))}]
% 'eval', []
% 'num_pts', [3]
% 'save_fields', [0]
% 'silent', [0]
% 'unattended_param', [1]
% 'unattended_freq', [1]
%
% Additional information:
% - At least one solver must exist within the mph model (given by the default tag
%   'sol1'). If a second solver exists, and is active, it must be given by the tag
%   'sol2' (which again, is the default from COMSOL). The case of one or
%   two solvers is automatically detected by the functions so long as the
%   tag names are correct.
%
% - The currently stored solution(s) must be at the starting frequency of the
%   sweep

import com.comsol.model.*
import com.comsol.model.util.*

%% Constants
DEFAULT_NUM_TRANS_POINTS = 3;
FMT_CMPLX='%+.4f%+.4fj';
FMT_FREQUENCY='%.3E';
DEFAULT_MODE_RULES={...
    'lambda', @(x) x>1;
    'lambda', @(x) abs(imag(x))<=1.01*abs(real(x))};

%% Parse inputs
inparser=inputParser;
addRequired(inparser,'sweep',@isstruct);
addRequired(inparser,'freqs',@isnumeric);
addParamValue(inparser,'mph','',@ischar);
addParamValue(inparser,'lambda_search',nan,@isnumeric);
addParamValue(inparser,'savedat','',@ischar);
addParamValue(inparser,'savedir','./data/',@ischar);
addParamValue(inparser,'mode_rules',DEFAULT_MODE_RULES,@iscell);
addParamValue(inparser,'eval',cell(1,0),@iscell);
addParamValue(inparser,'num_pts',DEFAULT_NUM_TRANS_POINTS,@isnumeric);
addParamValue(inparser,'save_fields',0,@isnumeric);
addParamValue(inparser,'silent',0,@isnumeric);
addParamValue(inparser,'unattended_param',1,@isnumeric);
addParamValue(inparser,'unattended_freq',1,@isnumeric);
parse(inparser,varargin{:});
in=inparser.Results;

%% Output struct
output.inputs=in;
output.time=clock();

%% Main state machine loop

% Index variables used within this loop:
% f - current frequency index
% p - current parameter value set index
% t - current parameter value set transition index

StateMgr=MPH_ModeTracker_StateMgr();
while 1
    doStateTransition(StateMgr);
    switch StateMgr.current
        case MPH_ModeTracker_State.Start
            %% ---
            % Comsol
            try
                mphstart();
                ModelUtil.showProgress(true);
                fprintf('(#) Successfully connected to COMSOL\n');
                [m,in.mph] = mphload_enhanced(in.mph);
                StateMgr.next=MPH_ModeTracker_State.Setup;
            catch
                fprintf('(!) Failed connecting to COMSOL and/or loading model from file\n');
                StateMgr.next=MPH_ModeTracker_State.Exit;
            end
            
            % Save settings
            if isempty(in.savedat)
                [~, in.savedat, ~] = fileparts(pwd);
            end
            mat_savename = [ fileparts(in.savedir),'/',in.savedat,'_',sprintf('%d-%d-%d_%d-%d',output.time(1),output.time(2),output.time(3),output.time(4),output.time(5)) ];
            [~,unique_output_var_name,~] = fileparts(in.mph);
            unique_output_var_name=['output_',unique_output_var_name];
            
            fprintf('(#) Results saved to ''%s''\n',mat_savename);
            fprintf('(#) Unique output variable name is ''%s''\n',unique_output_var_name);
            
            % Pushover.net notifications
            PN=PushoverNotifier(in.savedat);
            if in.silent
                PN.enableSilent();
            end
            
        case MPH_ModeTracker_State.Setup
            %% ---
            COMSOLSlvrMgr=MPH_ModeTracker_COMSOLSolverMgr(2);
            COMSOLSlvrMgr.detectSolvers(m);
            
            lambda_search=in.lambda_search;
            if isnan(lambda_search) % if not specified, pull from model
                tmpev = m.param.evaluateComplex('lambda_search');
                lambda_search = tmpev(1) + 1j*tmpev(2);
            end
            
            param_names   = fieldnames(in.sweep);
            N_param_names = length( param_names );
            N_param_vals  = length(in.sweep.( param_names{1} ));
            % NOTE: we have assumed that each parameter to be swept has an equivalent
            % number of values as all other parameters that are to be swept.
            % i.e.   sweep.a = [1 2 3 4];
            %        sweep.b = [5 6 7 8];  results in the combinations being simulated:
            %        (a,b)=(1,5),(2,6),(3,7),(4,8)
            param_vals_current = NaN(N_param_names,1);
            param_vals_future  = NaN(N_param_names,N_param_vals);
            for n=1:N_param_names
                tmpev = m.param.evaluateComplex(param_names{n});
                param_vals_current(n) = tmpev(1) + 1j*tmpev(2);
                for k=1:N_param_vals
                    param_vals_future(n,k) = in.sweep.(param_names{n})(k);
                end
            end
            StateMgr.next=MPH_ModeTracker_State.NewParam;
            
        case MPH_ModeTracker_State.NewParam
            %% ---
            freqs_working=in.freqs;
            f=1;
            t=1;
            if ~exist('p','var') %first param set
                p=1;
            else %second or later param sets
                p=p+1;
                lambda_search=output.lambda{p-1}(f); %rewind frequency
            end
            
            if p <= N_param_vals
                fprintf('Start of parameter set {');
                
                flg_need_transition = 0;
                pram_vals_transition = NaN(N_param_names,in.num_pts);
                for n = 1:N_param_names
                    fprintf('%s, ',param_names{n});
                    if param_vals_current(n) ~= param_vals_future(n,p)
                        flg_need_transition = 1;
                    end
                    pram_vals_transition(n,:)=linspace( param_vals_current(n), param_vals_future(n,p), in.num_pts );
                end
                fprintf('\b\b} = {');
                for n = 1:N_param_names
                    fprintf('%d, ',param_vals_future(n,p));
                end
                fprintf('\b\b} ---------- (%d/%d)\n',p,N_param_vals);
                
                if flg_need_transition
                    StateMgr.mode=MPH_ModeTracker_SweepMode.Param;
                    StateMgr.next=MPH_ModeTracker_State.StepParam;
                else
                    StateMgr.mode=MPH_ModeTracker_SweepMode.Freq;
                    StateMgr.next=MPH_ModeTracker_State.Compute;
                end
            else %No more param value sets to run
                StateMgr.next=MPH_ModeTracker_State.Exit;
            end
            
        case MPH_ModeTracker_State.StepParam
            %% ---
            t=t+1;
            if t <= size(pram_vals_transition,2)
                StateMgr.next=MPH_ModeTracker_State.RunParam;
            else
                StateMgr.mode=MPH_ModeTracker_SweepMode.Freq;
                StateMgr.next=MPH_ModeTracker_State.Extract;
            end
            
        case MPH_ModeTracker_State.RunParam
            %% ---
            fprintf('Transition parameter set {');
            for n = 1:N_param_names
                fprintf('%s, ',param_names{n});
                param_vals_current(n)=pram_vals_transition(n,t);
            end
            
            fprintf('\b\b} = {');
            for n = 1:N_param_names
                fprintf('%d, ',pram_vals_transition(n,t));
            end
            fprintf('\b\b} (%d/%d)\n',t,size(pram_vals_transition,2));
            StateMgr.next=MPH_ModeTracker_State.Compute;
            
        case MPH_ModeTracker_State.StepFreq
            %% ---
            f=f+1;
            if f <= length(freqs_working)
                StateMgr.next=MPH_ModeTracker_State.RunFreq;
            else
                StateMgr.next=MPH_ModeTracker_State.NewParam;
            end
            
        case MPH_ModeTracker_State.RunFreq
            fprintf(['Running frequency ',FMT_FREQUENCY,' (%d/%d)\n'],freqs_working(f),f,length(freqs_working));
            StateMgr.next=MPH_ModeTracker_State.Compute;
            
        case MPH_ModeTracker_State.Compute
            %% ---
            clear param_pass_struct;
            pass_struct.freq0         = freqs_working(f);
            pass_struct.lambda_search = lambda_search;
            for n=1:N_param_names
                pass_struct.(param_names{n})=param_vals_current(n);
            end
            m=passConfiguration(m,pass_struct);
            try
                m.sol( COMSOLSlvrMgr.solver_tag() ).runAll;
                lambda_computed = mphglobal(m,'lambda','Complexout','on','Dataset',COMSOLSlvrMgr.dataset_tag());
                fprintf(['Computed lambda = ',FMT_CMPLX,'\n'],real( lambda_computed ),imag( lambda_computed ) );
                StateMgr.next=MPH_ModeTracker_State.Validate;
            catch err
                [regexp_tokens,~]=regexp(err.message,'Exception:\n\s(.*)','tokens','match','dotexceptnewline');
                fprintf('(!) Error originating from COMSOL: %s\n',regexp_tokens{1}{1});
                StateMgr.next=MPH_ModeTracker_State.Retry;
            end
            
        case MPH_ModeTracker_State.Validate
            %% ---
            if ( isParamTrackActive(StateMgr.mode) && ~in.unattended_param )||...
                    ( isFreqTrackActive(StateMgr.mode) && ~in.unattended_freq )
                StateMgr.next=MPH_ModeTracker_UserModePrompt(m,COMSOLSlvrMgr.plotgroup_tag(),PN);
            else
                StateMgr.next=MPH_ModeTracker_State.Extract;
                fprintf('Validating mode... ');
                nbsp=fprintf('\n');
                N_rules=size(in.mode_rules,1);
                for rule=1:N_rules
                    fprintf(repmat('\b',1,nbsp));
                    nbsp=fprintf('(%d/%d)\n',rule,N_rules);
                    evaluee_name=in.mode_rules{rule,1};
                    func_validation_rule=in.mode_rules{rule,2};
                    try
                        evaluee_value= mphglobal(m,evaluee_name,'Complexout','on','Dataset',COMSOLSlvrMgr.dataset_tag());
                    catch
                        fprintf('(!) Calling mphglobal() on ''%s'' failed!\n',evaluee_name);
                        StateMgr.next=MPH_ModeTracker_State.Exit;
                        break
                    end
                    
                    if ~func_validation_rule( evaluee_value )
                        fprintf('(!) Validation failed on %s = %d\n',evaluee_name,evaluee_value);
                        StateMgr.next=MPH_ModeTracker_State.Retry;
                        break
                    end
                end
            end
            
        case MPH_ModeTracker_State.Extract
            %% ---
            if isFreqTrackActive(StateMgr.mode)
                output.freqs{p}(f)  = freqs_working(f);
                output.lambda{p}(f) = lambda_computed;
                
                for k=1:length(in.eval)
                    CurrentEval=in.eval{k};
                    try
                        output.(CurrentEval){p}(f)= mphglobal(m,CurrentEval,'Complexout','on','Dataset',COMSOLSlvrMgr.dataset_tag());
                    catch
                        fprintf(['(!) Unable to extract result ', CurrentEval,'\n']);
                    end
                end
                
                % Save data
                fprintf('Saving ');
                if in.save_fields==1
                    fprintf('field patterns, ');
                    freq_text=sprintf('freq=%.2e',freqs_working(f));
                    param_text=sprintf('p=%d',p);
                    plotCOMSOLPlotGroup(m,COMSOLSlvrMgr.plotgroup_tag(), fullfile(mat_savename,['/',param_text,'_',freq_text]) );
                end
                fprintf('result data...\n');
                eval([unique_output_var_name,'=output;']);
                save(mat_savename,unique_output_var_name,'output');
                
                StateMgr.next=MPH_ModeTracker_State.StepFreq;
            else
                StateMgr.next=MPH_ModeTracker_State.StepParam;
            end
            
            StateMgr.resetRetries();
            lambda_search=lambda_computed;
            COMSOLSlvrMgr.step(); % Always use the next solver
            
        case MPH_ModeTracker_State.Retry
            %% ---
            incRetries(StateMgr);
            if exceedeMaxRetries(StateMgr)
                fprintf('(!) Reached maximum number of retries\n');
                PN.ErrorNotify('Reached maximum number of retries');
                StateMgr.next=MPH_ModeTracker_State.NewParam;
                continue
            end
            
            if isParamTrackActive(StateMgr.mode)
                if  t > 1
                    new_param_vals_transition = NaN(N_param_names,1);
                    for n = 1:N_param_names
                        new_param_vals_transition(n)=pram_vals_transition(n,t-1)+(pram_vals_transition(n,t)-pram_vals_transition(n,t-1))/2;
                    end
                    if StateMgr.retries==1 % On first retry we insert new vector
                        pram_vals_transition=[pram_vals_transition(:,1:t-1), new_param_vals_transition, pram_vals_transition(:,t:size(pram_vals_transition,2))];
                    else % On second or later retry we don't need to "grow" the array, just insert over previous retry/retries
                        pram_vals_transition(:,t)=new_param_vals_transition;
                    end
                    for n = 1:N_param_names
                        param_vals_current(n)=pram_vals_transition(n,t);
                    end
                    fprintf('Retry %d/%d at interpolated parameter set after failure at ''%s''\n',StateMgr.retries,StateMgr.retriesMax,char(StateMgr.last));
                    StateMgr.next=MPH_ModeTracker_State.RunParam;
                else
                    fprintf('(!) Can''t attempt to retry at first param!\n');
                    StateMgr.next=MPH_ModeTracker_State.NewParam;
                end
            else % FREQ
                if f > 1
                    new_local_freq = freqs_working(f-1)+(freqs_working(f)-freqs_working(f-1))/2;
                    if StateMgr.retries==1 % On first retry we insert new frequency
                        freqs_working=[freqs_working(1:f-1), new_local_freq, freqs_working(f:length(freqs_working))];
                    else % On second or later retry we don't need to "grow" the array, just insert over freq of previous retry/retries
                        freqs_working(f)=new_local_freq;
                    end
                    fprintf(['Retry %d/%d at interpolated frequency (',FMT_FREQUENCY,') after failure at ''%s''\n'],StateMgr.retries,StateMgr.retriesMax,new_local_freq,char(StateMgr.last));
                    StateMgr.next=MPH_ModeTracker_State.RunFreq;
                else
                    fprintf('(!) Can''t attempt to retry at first freq!\n');
                    StateMgr.next=MPH_ModeTracker_State.NewParam;
                end
            end
            
        case MPH_ModeTracker_State.Exit
            %% ---
            output.m=m;
            PN.TimedNotify();
            break
            
        otherwise
            fprintf('(!) Unhandled state in state machine: ''%s''\n',char(StateMgr.current));
            break
            
    end
end
end