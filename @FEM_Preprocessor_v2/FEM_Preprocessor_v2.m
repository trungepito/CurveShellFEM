classdef FEM_Preprocessor_v2 < handle
    properties
        % --- TOPOLOGY DATA ---
        GeoPoints   % Nx3 Keypoints
        GeoLines    % Cell array of line definitions
        GeoPatches  % Cell array of patch definitions

        % --- MESH DATA ---
        Mesh        % Struct: .Nodes, .Elements, .Normals

        % --- PHYSICS DATA ---
        Material    % Struct: .E, .nu, .t
        % to generalize this data let move to the table format!!!
        BCs = table([],[],[],[], 'VariableNames', {'Node','DOF','Value','Tag'})
        % [NodeID, DOF, Value,Tag] this also move to the table format
        Loads=table([],[],[],[], 'VariableNames', {'Node','DOF','Value','Tag'});
    end

    methods
        function obj = FEM_Preprocessor_v2(E, nu, t)
            obj.Material = struct('E', E, 'nu', nu, 't', t);
            % Init Empty Arrays
            obj.GeoPoints = zeros(0,3);
            obj.GeoLines = {};
            obj.GeoPatches = {};
            obj.Mesh.Nodes = zeros(0,3);
            obj.Mesh.Elements = int32(zeros(0,8));

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
        %  MODULE 3: SELECTION (THE "PICKER")
        ids = selectNodesByBox(obj, xmin, xmax, ymin, ymax, zmin, zmax)
        ids = selectNodesByCylinder(obj, axis, center, radius, tol)
        ids = selectNodesOnPlane(obj, dim, val, tol)
        elemIDs = selectElementsByBox(obj, boxBounds)
    end
    methods
        % Apply physical conditions Loads and Boundary conditions
        % --- CONSTRAINT METHODS ---
        addBC(obj,nodes, dofs, value,tag)
        addNodalLoad(obj, nodeIDs, dof, val,tag)
        addDistributedLoad(obj, elemIDs, loadVector,tag)
        addPressureLoad(obj, elemIDs, magnitude,tag)
        integrateSurfaceLoad(obj, elemIDs, funcHandle, type,tag)
    end
    methods
        % ADVANCED METHODS Combine geometry and mesh
        createExtrusion(obj, profileNodes, profileSegs, direction, extrudeSpecs, meshDensityZ)
    end

end