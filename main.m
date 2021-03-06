function [da,fw,da_list,fw_list]=main(filename)
% Description:
% function [sol,stats] = main(filename)
% input: filename of input selected by users
% output:
% check input type
if isa(filename,'char')
    % Convert information from txt into a structure "param"
    param=get_prm(filename);
elseif isa(filename,'struct')
    param = filename;
else
    error('input must be a filename or a structure');
end

% translate kernel type in .txt file to "param"
param.kernel = common.getKernel(param);

% update regularization parameters
if isfield(param,'theta_Q') && isfield(param,'theta_R')
    param.theta = [param.theta_Q/param.theta_R, param.theta_R];
end

%% Initialization
% Map simulation parameters to FW subclass and create an object at time 0
fw = selectFW(param);
% Use mexBBFMM2D for covariance matrix multiplication
if isfield(param,'mexBBFMM') && param.mexBBFMM == true
%    construct kernelfun for fw.kernel
    addpath('./mexBBFMM2D/')
    if isprop(fw,'kernel')
        syms h;
        kernel = sym(fw.kernel);
        outputfile = param.mexfile_name;
        cd ./mexBBFMM2D/
        make(h,kernel,outputfile);
        copyfile('./expfun.mexmaci64','../+common/','f');
        cd ../
    end
end
% Map inversion parameters to DA subclass and create an object at time 0
da = selectDA(param,fw);
% Initialize SSM
da = fw.initializeSSM(da,param);
da = da.addRegularization(param);

% TODO: check if fw and da contain all the necessary properties and functions after initialization
rng(100);

% note that da and fw are objects of a handle class, cannot make a copy
% therefore, save a copy by converting the properties to structure,this
% will however display all private field, and issue warning, to suppress
% the warning, use
warning('off','MATLAB:structOnObject');
da_list = cell(param.nt+1,1);
fw_list = cell(param.nt+1,1);
da_list{1} = struct(da);
fw_list{1} = struct(fw);

% major assimilation loop
for i = 1:param.nt
    %% Run truemodel to produce true state xt and data z, save as property of fw
    % call f and h to update state and observation
    [fw.xt, fw.zt] = fw.simulate(fw.xt);
    
    %% Run data assimilation to get solution x and its uncertainty, save as property of da
    if isfield(param,'smooth') && param.smooth == true
        da.smooth(fw);
        da.forecast(fw);
    else
        da.predict(fw);
        da.update(fw);
    end
    
    da_list{i+1}  = struct(da);
    fw_list{i+1}  = struct(fw);
    % save fw and da as snapshots for analysis
    
end
if ismethod(fw,'visualize')
    fw.visualize(fw_list,da_list)
end

end
