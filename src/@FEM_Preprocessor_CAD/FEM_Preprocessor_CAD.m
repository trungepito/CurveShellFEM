classdef FEM_Preprocessor_CAD < FEM_Preprocessor
    properties
        % --- GEOMETRY STORAGE ---
        GeoPoints   % Nx3 Matrix of geometric keypoints
        GeoLines    % Cell Array of structs {Type, P1, P2, ControlPoints...}
        GeoPatches  % Cell Array of structs {LineIDs, Type...}
    end

    methods
        function obj = FEM_Preprocessor_CAD(E, nu, t)
            obj@FEM_Preprocessor(E, nu, t);
            obj.GeoPoints = zeros(0,3);
            obj.GeoLines = {};
            obj.GeoPatches = {};
        end
    end
    methods
        id = addPoint(obj, x, y, z)
        id = addLine(obj, p1_id, p2_id, type, varargin)
        id = addPatch(obj, l1, l2, l3, l4)
    end
    methods
        meshQuadPatch(obj, patchID, Nu, Nv)
        pts = discretizeLine(obj, lineID, nPts)
        mergeDuplicateNodes(obj, tol)
    end
    methods
        createPlateWithHole(obj, L, R, Nu, Nv)
    end
    methods
        applyBC_OnLine(obj, lineID, dofs)
        applyDistributedLoad(obj, lineID, totalForceMag, directionVec)
        nIDs = findNodesOnLine(obj, lineID)
    end
end