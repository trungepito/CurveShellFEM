function Pre = loadPreprocessor_(obj)
preFile = fullfile(obj.ProjectRoot_, 'preprocessor.mat');
if ~exist(preFile, 'file')
    error('[DataMgr] preprocessor.mat not found at %s', preFile);
end
fprintf('[DataMgr] Loading preprocessor from %s...\n', preFile);
data = load(preFile);
mat  = data.Material;
Pre  = FEM_Preprocessor_v2(mat.E, mat.nu, mat.t);
Pre.Mesh  = data.Mesh;
Pre.BCs   = data.BCs;
Pre.Loads = data.Loads;
if isfield(data,'GeoPoints'),  Pre.GeoPoints  = data.GeoPoints;  end
if isfield(data,'GeoLines'),   Pre.GeoLines   = data.GeoLines;   end
if isfield(data,'GeoPatches'), Pre.GeoPatches = data.GeoPatches; end
if isfield(mat,'Type') && strcmp(mat.Type,'J2Plastic') ...
   && isfield(mat,'Obj')
    Pre.Material = mat;
end
end
