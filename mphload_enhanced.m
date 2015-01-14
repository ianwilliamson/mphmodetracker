function [m, model_fn]  = mphload_enhanced( model_fn )
import com.comsol.model.*
import com.comsol.model.util.*
try
    m=mphload(model_fn);
catch err
    [FileName,PathName]=uigetfile('./*.mph');
    model_fn=[PathName,FileName];
    m=mphload(model_fn);
end
fprintf('(#) Successfully loaded COMSOL model from ''%s''\n',model_fn);
end

