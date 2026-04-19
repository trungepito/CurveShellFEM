function Pre = make_plate_model(varargin)
% MAKE_PLATE_MODEL  Build a simple flat square plate FEM_Preprocessor_v2.
%
% Parameters (name-value):
%   'E'       Young's modulus          (default 2.1e11 Pa)
%   'nu'      Poisson ratio            (default 0.3)
%   't'       thickness                (default 0.01 m)
%   'L'       side length              (default 1.0 m)
%   'Ne'      elements per side        (default 4)
%   'bc'      BC type: 'clamped'|'ss'  (default 'clamped')
%   'plastic' add J2 plasticity        (default false)
%   'sigY'    yield stress (Pa)        (default 250e6)
%   'H'       isotropic hardening (Pa) (default 0)

p = inputParser();
p.addParameter('E',    2.1e11);
p.addParameter('nu',   0.3);
p.addParameter('t',    0.01);
p.addParameter('L',    1.0);
p.addParameter('Ne',   4);
p.addParameter('bc',   'clamped');
p.addParameter('plastic', false);
p.addParameter('sigY', 250e6);
p.addParameter('H',    0);
p.parse(varargin{:});
r = p.Results;

Pre = FEM_Preprocessor_v2(r.E, r.nu, r.t);
Pre.createPlate([0, 0, 0], r.L, r.L);
Pre.meshAllPatches(r.Ne, r.Ne);

if r.plastic
    Pre.setMaterialPlastic(r.sigY, r.H);
end

switch lower(r.bc)
    case 'clamped'
        % All 6 DOFs fixed on all 4 edges
        edge_nodes = unique([ ...
            Pre.selectNodesOnPlane(1, 0,    1e-4); ...
            Pre.selectNodesOnPlane(1, r.L,  1e-4); ...
            Pre.selectNodesOnPlane(2, 0,    1e-4); ...
            Pre.selectNodesOnPlane(2, r.L,  1e-4)]);
        Pre.addBC(edge_nodes, 1:6, 0, 'Clamp');

    case 'ss'
        % Simply supported: fix uz + rotations, pin one corner for in-plane stability
        edge_x0 = Pre.selectNodesOnPlane(1, 0,    1e-4);
        edge_xL = Pre.selectNodesOnPlane(1, r.L,  1e-4);
        edge_y0 = Pre.selectNodesOnPlane(2, 0,    1e-4);
        edge_yL = Pre.selectNodesOnPlane(2, r.L,  1e-4);
        all_edges = unique([edge_x0; edge_xL; edge_y0; edge_yL]);
        Pre.addBC(all_edges, 3, 0, 'SS_uz');
        Pre.addBC(all_edges, 4, 0, 'SS_rx');
        Pre.addBC(all_edges, 5, 0, 'SS_ry');
        corner = Pre.selectNodesByBox(-1e-4, 1e-4, -1e-4, 1e-4, -1e-4, 1e-4);
        Pre.addBC(corner, [1, 2], 0, 'Pin');

    otherwise
        error('make_plate_model:badBC', 'bc must be ''clamped'' or ''ss''');
end
end
