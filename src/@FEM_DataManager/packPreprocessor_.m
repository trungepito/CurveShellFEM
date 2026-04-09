function PreData = packPreprocessor_(~, Pre)
PreData.Mesh     = Pre.Mesh;
PreData.Material = Pre.Material;
if ~isempty(Pre.BCs)
    PreData.BCs = Pre.BCs;
else
    PreData.BCs = table([],[],[],{}, ...
        'VariableNames',{'Node','DOF','Value','Tag'});
end
if ~isempty(Pre.Loads)
    PreData.Loads = Pre.Loads;
else
    PreData.Loads = table([],[],[],{}, ...
        'VariableNames',{'Node','DOF','Value','Tag'});
end
% Preserve geometry data if present (v2 preprocessor)
if isprop(Pre,'GeoPoints'),  PreData.GeoPoints  = Pre.GeoPoints;  end
if isprop(Pre,'GeoLines'),   PreData.GeoLines   = Pre.GeoLines;   end
if isprop(Pre,'GeoPatches'), PreData.GeoPatches = Pre.GeoPatches; end
end
