classdef FEM_Preprocessor < handle
    properties
        Mesh        % Struct: .Nodes, .Elements, .Normals
        Material    % Struct: .E, .nu, .t
        BCs         % Matrix: [NodeID, DOF_Index] (Constraints)
        Loads       % Matrix: [NodeID, DOF_Index, Value] (Forces)
    end

    methods
        function obj = FEM_Preprocessor(E, nu, t)
            obj.Material.E = E;
            obj.Material.nu = nu;
            obj.Material.t = t;
            obj.Mesh.Nodes = [];
            obj.Mesh.Elements = [];
            obj.BCs = [];
            obj.Loads = [];
        end
    end
    methods
        generateCylinderMesh(obj, R, L, Nu, Nv)
        computeNormals(obj)
    end

    methods
        function addConstraint(obj, nodeID, dof)
            obj.BCs = [obj.BCs; nodeID, dof];
        end

        function addLoad(obj, nodeID, dof, val)
            obj.Loads = [obj.Loads; nodeID, dof, val];
        end
    end

end