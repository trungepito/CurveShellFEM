classdef GeometryEngine
% GEOMETRYENGINE Static factory class for CAD generation
% Separated from FEM_Preprocessor_v2 to enforce modularity.
    methods (Static)
        createCylinderPanel(Pre, R, H, angleStart, angleEnd)
        createExtrusion(Pre, profileNodes, profileSegs, direction, extrudeSpecs, meshDensityZ)
        createIBeam(Pre, H, W, L, numseg, meshz)
        createPlate(Pre, origin, Lx, Ly)
        createPlateWithHole(Pre, L, R)
    end
end
