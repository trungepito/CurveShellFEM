function buildElementCache(obj)
            % BUILDELEMENTCACHE Pre-builds element objects and scatter maps
            m = obj.Model.Mesh;
            mat = obj.Model.Material;
            nElems = size(m.Elements, 1);
            obj.Elements = cell(nElems, 1);
            obj.SctrMap = zeros(nElems, 48);
            for e = 1:nElems
                idx = m.Elements(e, :);
                el_coords = m.Nodes(idx, :);
                el_normals = m.Normals(idx, :);
                % Phase 9/10 Dynamic Element Selection
                useANS_EAS = isfield(mat, 'ElementType') && strcmp(mat.ElementType, 'ANS_EAS');
                
                if isfield(mat, 'Type') && strcmp(mat.Type, 'J2Plastic') && isfield(mat, 'Obj')
                    nGP = 4 * 5; 
                    init_h = struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0);
                    hist = repmat(init_h, nGP, 1);
                    if useANS_EAS
                        obj.Elements{e} = Curve8Element_ANS_EAS(el_coords, el_normals, mat.t, mat.E, mat.nu, mat.Obj, hist);
                    else
                        obj.Elements{e} = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu, mat.Obj, hist);
                    end
                else
                    if useANS_EAS
                        obj.Elements{e} = Curve8Element_ANS_EAS(el_coords, el_normals, mat.t, mat.E, mat.nu);
                    else
                        obj.Elements{e} = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu);
                    end
                end
                sctr = zeros(1, 48);
                for n = 1:8
                    start_dof = (double(idx(n)) - 1) * 6;
                    local_start = (n - 1) * 6;
                    sctr(local_start+1 : local_start+6) = start_dof + (1:6);
                end
                obj.SctrMap(e, :) = sctr;
            end