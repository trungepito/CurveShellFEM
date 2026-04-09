function tf = matHasVar_(~, matFile, varName)
try
    info = whos('-file', matFile);
    tf   = any(strcmp({info.name}, varName));
catch
    tf = false;
end
end
