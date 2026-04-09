function s = readJSON_(~, filepath)
% Read a JSON file into a MATLAB struct.
fid = fopen(filepath, 'r');
if fid == -1
    error('[DataMgr] Cannot open: %s', filepath);
end
raw = fread(fid, '*char')';
fclose(fid);
s = jsondecode(raw);
end
