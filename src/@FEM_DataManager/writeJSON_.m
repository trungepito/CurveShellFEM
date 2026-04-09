function writeJSON_(~, filepath, s)
% Write a MATLAB struct to a JSON file (pretty-printed).
fid = fopen(filepath, 'w');
if fid == -1
    error('[DataMgr] Cannot write: %s', filepath);
end
fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
fclose(fid);
end
