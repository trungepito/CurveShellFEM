function [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
% ASSEMBLETANGENTSYSTEM Unified assembly of Global KT, F_int, and Trial History
% If U_curr is not provided, uses obj.U (standard for nonlinear solvers)

if nargin < 2
    U_curr = obj.U;
end

nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;

% Use triplet assembly for speed
nElems = size(obj.Model.Mesh.Elements, 1);
nz_per_elem = 48*48;
estnz = int32(nz_per_elem * nElems);
I = zeros(estnz, 1); J = zeros(estnz, 1); V = zeros(estnz, 1);
count = 0;

F_int = zeros(nDofs, 1);
TrialHist = cell(nElems, 1); % Store trial states

for e = 1:nElems
    sctr = obj.SctrMap(e, :);

    % Extract Current Element Displacement
    u_el = zeros(48, 1);
    for n = 1:8
        g_dof = (obj.Model.Mesh.Elements(e, n)-1)*6;
        u_el((n-1)*6 + (1:6)) = U_curr(g_dof + (1:6));
    end

    % Use cached element object
    elObj = obj.Elements{e};

    % CALL THE ELEMENT METHOD
    [KT_global, fe, NewHist] = elObj.computeGlobalMatrix6DOF(u_el);
    TrialHist{e} = NewHist;

    % Assemble F_int
    F_int(sctr) = F_int(sctr) + fe;
    
    % Assemble KT triplets
    [ii, jj] = meshgrid(sctr, sctr);
    range = count + (1:nz_per_elem);
    I(range) = ii(:);
    J(range) = jj(:);
    V(range) = KT_global(:);
    count = count + nz_per_elem;
end

KT = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);

end
