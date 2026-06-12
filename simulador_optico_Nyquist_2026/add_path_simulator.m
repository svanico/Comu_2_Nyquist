
%-----------------------------------------------------------------------------%
%                                   ADD PATH 
%-----------------------------------------------------------------------------%

proj_dir = mfilename('fullpath');
proj_dir = proj_dir(1: end - length(mfilename));

addpath(genpath([proj_dir, 'modulos/']))
addpath(genpath([proj_dir, 'tools/']))