function ids = selectNodesOnPlane(obj, dim, val, tol)
% dim: 1=X, 2=Y, 3=Z
if nargin < 4, tol = 1e-4; end
ids = find(abs(obj.Mesh.Nodes(:,dim) - val) < tol);
end