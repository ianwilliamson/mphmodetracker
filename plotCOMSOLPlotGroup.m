function plotCOMSOLPlotGroup(m,plotGroup,filename,varargin)
f=figure('Name',plotGroup,'Position',[100,100,650,650],'Color',[1 1 1],'MenuBar','none','Visible','Off');
mphplot(m,plotGroup);
set(gca(),'Parent',f);

savefigure_hq(f,[filename,'_iso.png']);
delete([filename,'_iso.eps']);
% view(gca(),[00 90]);
% savefigure_hq(f,[filename,'_00-90.png']);
% delete([filename,'_00-90.eps']);
% view(gca(),[00 00]);
% savefigure_hq(f,[filename,'_00-00.png']);
% delete([filename,'_00-00.eps']);
% view(gca(),[90 00]);
% savefigure_hq(f,[filename,'_90-00.png']);
% delete([filename,'_90-00.eps']);

close(f);

end