function [m, model_fn]  = mphload_enhanced( model_fn, varargin )
import com.comsol.model.*
import com.comsol.model.util.*

if nargin>1
    model_tag = varargin{1};
else
    [~,model_tag]=fileparts(model_fn);
end

try
    m=mphload(model_fn,model_tag);
catch err
    if ~isempty( strfind(err.message,'could not be found') )
        [FileName,PathName]=uigetfile('./*.mph');
        model_fn=[PathName,FileName];
        m=mphload(model_fn,model_tag);
    else
        err.rethrow();
    end
end
fprintf('# Loaded ''%s''\n',model_fn);
fprintf('# Assigned model tag: ''%s''\n',model_tag);
end

