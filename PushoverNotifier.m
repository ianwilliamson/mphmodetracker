classdef PushoverNotifier < handle
    properties (SetAccess = private)
        CONST_TOKEN='lyYprsfuDPfHHrDgl5bCtdAkhMHekw';
        CONST_USER='';
        MinimumElapsedTime=60; % minutes that must elapse in order to a TimedNotify to be dispatched
        StartTime
        ApplicationName
        Silent=0;
        Disabled=0;
    end
    %% Public methods
    methods
        % Init
        function PN = PushoverNotifier(ApplicationName,MinimumElapsedTime)
            PN.StartTime=clock();
            PN.ApplicationName=ApplicationName;
            
            PN.CONST_USER=getenv('PUSHOVER_USER_TOKEN');
            if isempty(PN.CONST_USER)
                fprintf('(!) No ''PUSHOVER_USER_TOKEN'' enviornment variable. Pushover.net notifications will not be dispatched!\n')
                PN.Disabled=1;
            end
            if nargin>1
                PN.MinimumElapsedTime=MinimumElapsedTime;
            end
        end
        % Silent
        function toggleSlient(PN)
            setSilent(PN,~getSilent(PN));
        end
        function enableSilent(PN)
            setSilent(PN,1);
        end
        function disableSilent(PN)
            setSilent(PN,0);
        end
        function setSilent(PN,tf)
            PN.Silent=tf;
        end
        function tf=getSilent(PN)
            tf=PN.Silent;
        end
        % Messages
        function TimedNotify(PN)
            elapsedTime = etime(clock(),PN.StartTime);
            elapsedTimeString=PN.formatTimeString(elapsedTime);
            if elapsedTime/60 >= PN.MinimumElapsedTime
                doPushover(PN,['Completed in ', elapsedTimeString]);
            else
                fprintf(['(#): PushoverNotifier: TimedNotify called but sufficent time has not elapsed to dispatch notification\n']);
            end
        end
        function InfoNotify(PN,message)
            doPushover(PN,message)
        end
        function ErrorNotify(PN,message)
            doPushover(PN,message,1)
        end
        function AlarmNotify(PN,message)
            doPushover(PN,message,2)
        end
    end
    %% Private methods
    methods (Access = private)
        function doPushover(PN,message,priority)
            if nargin < 3
                priority=0;
            end
            params = {'token',   PN.CONST_TOKEN,...
                'user',    PN.CONST_USER,...
                'title',   PN.ApplicationName,...
                'message', message,...
                'priority', num2str(priority)};
            if priority==2
                params=[params,'retry','30','expire',num2str(60*4)];
            end
            if (~PN.Disabled && ~PN.Silent)
                try
                    urlread('https://api.pushover.net/1/messages.json', 'POST', params);
                catch error
                    fprintf(['(!): PushoverNotifier: Error connecting to Pushover API: ',error.identifier,'\n']);
                end
            end
        end
    end
    %% Static methods
    methods (Static)
        function timeString=formatTimeString(numberOfSeconds)
            timeString='';
            nhours = 0;
            nmins = 0;
            if numberOfSeconds >= 3600
                nhours = floor(numberOfSeconds/3600);
                if nhours > 1
                    hour_string = ' hours, ';
                else
                    hour_string = ' hour, ';
                end
                timeString = [num2str(nhours) hour_string];
            end
            if numberOfSeconds >= 60
                nmins = floor((numberOfSeconds - 3600*nhours)/60);
                if nmins > 1
                    minute_string = ' mins, ';
                else
                    minute_string = ' min, ';
                end
                timeString = [timeString num2str(nmins) minute_string];
            end
            nsecs = numberOfSeconds - 3600*nhours - 60*nmins;
            timeString = [timeString sprintf('%2.1f', nsecs) ' secs'];
        end
    end
end