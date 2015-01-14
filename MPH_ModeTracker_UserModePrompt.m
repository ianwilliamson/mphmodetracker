function NextState=MPH_ModeTracker_UserModePrompt(m,plot_group_tag,PushoverNotifier)
CONST_FONTSIZE=12;

NextState='CORRECT';
f = figure('Name','Mode Field Pattern','Position',[100,100,650,650],'Color',[1 1 1],'MenuBar','none','Visible','Off');
h_correct = uicontrol('Style','pushbutton',...
    'Units','normalized',...
    'String','Correct',...
    'Position',[0,0.9,0.33,0.1],...
    'BackgroundColor',[204/255, 255/255, 204/255],...
    'FontSize',CONST_FONTSIZE,...
    'Callback',{@correct_Callback});
h_stepback = uicontrol('Style','pushbutton',...
    'Units','normalized',...
    'String','Retry','Position',[0.33,0.9,0.33,0.1],...
    'BackgroundColor',[204/255, 229/255, 255/255],...
    'FontSize',CONST_FONTSIZE,...
    'Callback',{@retry_Callback});
h_abort = uicontrol('Style','pushbutton',...
    'Units','normalized',...
    'String','Abort','Position',[0.66,0.9,0.33,0.1],...
    'BackgroundColor',[255/255, 204/255, 204/255],...
    'FontSize',CONST_FONTSIZE,...
    'Callback',{@abort_Callback});

h_array=[h_correct,h_stepback,h_abort];

try
    mphplot(m,plot_group_tag);
    ha=gca();
    set(ha,'Parent',f,'Units','normalized','Position',[0.1 0.1 0.8 0.75]);
    rotate3d(ha);
    
catch err
    ha = uicontrol('Style','edit',...
        'String',['Failed to plot mode pattern: ',err.message],...
        'Max',2,'Min',0);
    set(ha,'Parent',f,'Units','normalized','Position',[0.1 0.1 0.8 0.75]);
    NextState='ABORT';
    set(f,'Visible','On');
    return;
end

PushoverNotifier.InfoNotify('Mode field pattern requires visual inspection');
timer1=timer('TimerFcn','PN.AlarmNotify(''Mode field pattern requires visual inspection'');',...
             'StartDelay',60*30);
set(f,'Visible','On');
start(timer1);
uiwait();

%% Clean up
try
    close(f);
catch
    
end

delete(timer1);
return

%% Function defs
    function correct_Callback(source,eventdata)
        NextState=MPH_ModeTracker_State.Extract;
        set(h_array,'Enable','off','Visible','off');
        uiresume();
    end
    function retry_Callback(source,eventdata)
        NextState=MPH_ModeTracker_State.Retry;
        set(h_array,'Enable','off','Visible','off');
        uiresume();
    end
    function abort_Callback(source,eventdata)
        NextState=MPH_ModeTracker_State.Exit;
        set(h_array,'Enable','off','Visible','off');
        uiresume();
    end

end