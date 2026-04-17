classdef FEM_Preprocessor_v2 < handle
% FEM_PREPROCESSOR_V2 - The primary geometric modeling and meshing interface.
%
% This class manages the creation of keypoints, lines, and patches, translates 
% them into an 8-node serendipity mesh, and applies BCs/Loads via a unified 
% table interface.
%
% Usage:
%   Pre = FEM_Preprocessor_v2(E, nu, t)
%   Pre.addKeypoint(0,0,0); Pre.addLine(1,2,'straight');
%   Pre.meshAllPatches(10, 10);
%
% See also: FEM_Solver, FEM_Postprocessor_v2
    properties
        % --- TOPOLOGY DATA ---
        GeoPoints   % Nx3 Keypoints
        GeoLines    % Cell array of line definitions
        GeoPatches  % Cell array of patch definitions

        % --- MESH DATA ---
        % Struct: .Nodes (double), .Elements (double), .Normals (double)
        Mesh

        % --- PHYSICS DATA ---
        Material    % Struct: .E, .nu, .t
        BCs = table([],[],[],[], 'VariableNames', {'Node','DOF','Value','Tag'})
        Loads=table([],[],[],[], 'VariableNames', {'Node','DOF','Value','Tag'});
    end

    methods
        function obj = FEM_Preprocessor_v2(E, nu, t)
            obj.Material = struct('E', E, 'nu', nu, 't', t);
            % Init Empty Arrays
            obj.GeoPoints = zeros(0,3);
            obj.GeoLines = {};
            obj.GeoPatches = {};
            obj.Mesh.Nodes = zeros(0,3, 'double');
            obj.Mesh.Elements = zeros(0,8, 'double');
            obj.Mesh.Normals = zeros(0,3, 'double');
        end
    end
    methods
        %  MODULE 1: GEOMETRY GENERATION
        id = addKeypoint(obj, x, y, z)
        id = addLine(obj, p1, p2, type, varargin)
        id = addPatch(obj, l1, l2, l3, l4)
        createPlate(obj, origin, Lx, Ly)
        createCylinderPanel(obj, R, H, angleStart, angleEnd)
        createPlateWithHole(obj, L, R)
        createIBeam(obj, H, W, L,numseg,meshz)
    end
    methods
        %  MODULE 2: MESHING
        meshAllPatches(obj, Nu, Nv)
        meshQuadPatch(obj, patchID, Nu, Nv)
        fuseNodes(obj, tol)
        pts = discretizeLine(obj, lineID, nPts)
        computeNormals(obj)
    end
    methods
        function setMaterialPlastic(obj, sigY, H_iso)
            obj.Material.Type = 'J2Plastic';
            obj.Material.Obj = Material_J2Plastic(obj.Material.E, obj.Material.nu, sigY, H_iso);
        end
    end
    methods
        %  MODULE 3: SELECTION (THE "PICKER")
        ids = selectNodesByBox(obj, xmin, xmax, ymin, ymax, zmin, zmax)
        ids = selectNodesByCylinder(obj, axis, center, radius, tol)
        ids = selectNodesOnPlane(obj, dim, val, tol)
        elemIDs = selectElementsByBox(obj, boxBounds)
    end
    methods
        % Apply physical conditions Loads and Boundary conditions
        addBC(obj,nodes, dofs, value,tag)
        addNodalLoad(obj, nodeIDs, dof, val,tag)
        addDistributedLoad(obj, elemIDs, loadVector,tag)
        addPressureLoad(obj, elemIDs, magnitude,tag)
        integrateSurfaceLoad(obj, elemIDs, funcHandle, type,tag)
    end
    methods
        % ADVANCED METHODS
        createExtrusion(obj, profileNodes, profileSegs, direction, extrudeSpecs, meshDensityZ)
        
        function applyImperfection(obj, modeShape, amplitude)
            % APPLYIMPERFECTION - Perturbs the mesh nodes using a mode shape.
            if size(modeShape, 1) ~= size(obj.Mesh.Nodes, 1)*6
                error('Mode shape size does not match mesh DOFs.');
            end
            dx = modeShape(1:6:end);
            dy = modeShape(2:6:end);
            dz = modeShape(3:6:end);
            mags = sqrt(dx.^2 + dy.^2 + dz.^2);
            scale = amplitude / max(mags);
            obj.Mesh.Nodes(:,1) = obj.Mesh.Nodes(:,1) + dx * scale;
            obj.Mesh.Nodes(:,2) = obj.Mesh.Nodes(:,2) + dy * scale;
            obj.Mesh.Nodes(:,3) = obj.Mesh.Nodes(:,3) + dz * scale;
            fprintf('[Preprocessor] Applied imperfection with max amplitude: %.3e\n', amplitude);
        end
    end
end