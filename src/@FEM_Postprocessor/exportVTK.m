function exportVTK(obj, filename)
% EXPORTVTK Dumps the current solver state to an XML .vtu file for ParaView
% High-performance binary-appended or ASCII fallback. 
% For reliability, we use standard ASCII XML serialization here.

if nargin < 2
    filename = 'CurveShellFEM_Output.vtu';
end

nodes = obj.Model.Mesh.Nodes;
elems = obj.Model.Mesh.Elements;
nNodes = size(nodes, 1);
nElems = size(elems, 1);
U = obj.Solver.U; % Current extracted displacement

fprintf('[VTK] Exporting %d elements and %d nodes to %s...\n', nElems, nNodes, filename);

% 1. Extract Field Data
% Deformed coordinates
U_xyz = [U(1:6:end), U(2:6:end), U(3:6:end)];
def_nodes = nodes + U_xyz;

% Nodal Smooth Stresses (Top Layer default)
s_vm = obj.recoverNodalSmooth('VonMises', 'Top');
s_ps1 = obj.recoverNodalSmooth('PrincipalStress1', 'Top');
s_ps2 = obj.recoverNodalSmooth('PrincipalStress2', 'Top');

% 2. Open File
fid = fopen(filename, 'w');
if fid == -1
    error('Cannot open file %s for writing.', filename);
end

% 3. Write XML Header
fprintf(fid, '<?xml version="1.0"?>\n');
fprintf(fid, '<VTKFile type="UnstructuredGrid" version="0.1" byte_order="LittleEndian">\n');
fprintf(fid, '  <UnstructuredGrid>\n');
fprintf(fid, '    <Piece NumberOfPoints="%d" NumberOfCells="%d">\n', nNodes, nElems);

% 4. Write Points (Nodal Coordinates)
fprintf(fid, '      <Points>\n');
fprintf(fid, '        <DataArray type="Float32" NumberOfComponents="3" format="ascii">\n');
% Write coordinates in a flattened row-major approach
fprintf(fid, '          %f %f %f\n', def_nodes');
fprintf(fid, '        </DataArray>\n');
fprintf(fid, '      </Points>\n');

% 5. Write Cells (Topology)
fprintf(fid, '      <Cells>\n');
fprintf(fid, '        <DataArray type="Int32" Name="connectivity" format="ascii">\n');
% VTK is 0-indexed. CurveShellFEM is 1-indexed.
vtkelems = elems - 1; 
fprintf(fid, '          %d %d %d %d %d %d %d %d\n', vtkelems');
fprintf(fid, '        </DataArray>\n');

fprintf(fid, '        <DataArray type="Int32" Name="offsets" format="ascii">\n');
% Offset is simply 8, 16, 24... for 8-node quads
offsets = 8:8:(nElems*8);
fprintf(fid, '          %d\n', offsets);
fprintf(fid, '        </DataArray>\n');

fprintf(fid, '        <DataArray type="Int32" Name="types" format="ascii">\n');
% VTK cell type 23 is Quadratic Quadrilateral (8 nodes)
types = repmat(23, 1, nElems);
fprintf(fid, '          %d\n', types);
fprintf(fid, '        </DataArray>\n');
fprintf(fid, '      </Cells>\n');

% 6. Write Point Data (Fields)
fprintf(fid, '      <PointData Vectors="Displacement" Scalars="VonMises">\n');

% Displacement Vector
fprintf(fid, '        <DataArray type="Float32" Name="Displacement" NumberOfComponents="3" format="ascii">\n');
fprintf(fid, '          %f %f %f\n', U_xyz');
fprintf(fid, '        </DataArray>\n');

% Von Mises Scalar
fprintf(fid, '        <DataArray type="Float32" Name="VonMises" format="ascii">\n');
fprintf(fid, '          %f\n', s_vm);
fprintf(fid, '        </DataArray>\n');

% Principal 1
fprintf(fid, '        <DataArray type="Float32" Name="PrincipalStress1" format="ascii">\n');
fprintf(fid, '          %f\n', s_ps1);
fprintf(fid, '        </DataArray>\n');

% Principal 2
fprintf(fid, '        <DataArray type="Float32" Name="PrincipalStress2" format="ascii">\n');
fprintf(fid, '          %f\n', s_ps2);
fprintf(fid, '        </DataArray>\n');

fprintf(fid, '      </PointData>\n');

% 7. Close XML
fprintf(fid, '    </Piece>\n');
fprintf(fid, '  </UnstructuredGrid>\n');
fprintf(fid, '</VTKFile>\n');

fclose(fid);
fprintf('[VTK] Successfully exported to %s.\n', filename);

end
