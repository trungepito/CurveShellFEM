function values = recoverPlasticFront(obj)
% RECOVERNODALSMOOTH_PLASTICFRONT - Calculates the yielded thickness ratio.
% Returns a scalar [nNodes x 1] representing the fraction (0-1) of 
% through-thickness points that have yielded.

nNodes = size(obj.Model.Mesh.Nodes, 1);
elems = obj.Model.Mesh.Elements;
nElems = size(elems, 1);
nGP_surf = 4; % 2x2
nPoints_thick = 5; % Simpson

% 1. Extract yielded fraction per Gauss Point
% gp_yielded is [nElems x nGP_surf]
gp_yield_frac = zeros(nElems, nGP_surf);

for e = 1:nElems
    if isa(obj.Solver.Elements{e}, 'Curve8Element_Plastic')
        hist = obj.Solver.Elements{e}.HistoryData; 
        for g = 1:nGP_surf
            % Count yielded points in this GP stack
            yield_count = 0;
            for k = 1:nPoints_thick
                idx = (g-1)*5 + k;
                if hist(idx).p > 1e-9
                    yield_count = yield_count + 1;
                end
            end
            gp_yield_frac(e, g) = yield_count / nPoints_thick;
        end
    end
end

% 2. Extrapolate from GPs to Nodes
% Extrapolation Matrix (4 Gauss points -> 8 Nodes)
gp = 1/sqrt(3);
xi_g  = [-gp,  gp,  gp, -gp];
eta_g = [-gp, -gp,  gp,  gp];
xi_n  = [-1,  1,  1, -1,  0,  1,  0, -1];
eta_n = [-1, -1,  1,  1, -1,  0,  1,  0];
E_mtx = zeros(8, 4);
for i = 1:8
    for j = 1:4
        E_mtx(i,j) = 0.25 * (1 + xi_n(i)*xi_g(j)*3) * (1 + eta_n(i)*eta_g(j)*3);
    end
end

% Flatten to element-wise nodal values
val_accum = zeros(8 * nElems, 1);
for g = 1:nGP_surf
    sig_val = gp_yield_frac(:, g);
    for n = 1:8
        val_accum(n:8:end) = val_accum(n:8:end) + E_mtx(n, g) * sig_val;
    end
end

% 3. Assemble globally
nodes_flat = double(elems');
nodes_flat = nodes_flat(:);
values = accumarray(nodes_flat, val_accum, [nNodes, 1]) ./ accumarray(nodes_flat, ones(size(val_accum)), [nNodes, 1]);

end
