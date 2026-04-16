classdef Assembler
% ASSEMBLER  Stateless finite element matrix assembly.
%
% All methods are static — no instance, no stored state.
% Inputs are explicit; outputs are returned. No side effects.
%
% Usage:
%   K  = Assembler.elastic(Elements, SctrMap, nDofs)
%   Kg = Assembler.geometric(U, Elements, SctrMap, nDofs)
%   [KT, F_int, TrialHist] = Assembler.tangent(U, Elements, SctrMap, nDofs)
%   F_int = Assembler.internalForce(U, Elements, SctrMap, nDofs)

    methods (Static)

        function K = elastic(Elements, SctrMap, nDofs)
        % ELASTIC  Assemble linear elastic stiffness matrix.
        % Elements: {nElems×1} cell of Curve8Element objects
        % SctrMap:  [nElems×48] scatter index map (double)
        % nDofs:    total number of DOFs (scalar)
        % Returns K: sparse [nDofs×nDofs]
            nElems = length(Elements);
            nz = 48*48*nElems;
            [ii_base, jj_base] = ndgrid(1:48, 1:48);
            ii_base = ii_base(:); jj_base = jj_base(:);
            I = zeros(nz, 1);
            J = zeros(nz, 1);
            V = zeros(nz, 1);
            count = 0;
            for e = 1:nElems
                Ke = Elements{e}.computeGlobalMatrix6DOF();
                sctr = SctrMap(e,:);
                range = count + (1:2304);
                I(range) = sctr(ii_base);
                J(range) = sctr(jj_base);
                V(range) = Ke(:);
                count = count + 2304;
            end
            K = sparse(I, J, V, nDofs, nDofs);
        end

        function Kg = geometric(U, Elements, SctrMap, nDofs)
        % GEOMETRIC  Assemble geometric stiffness matrix (for buckling).
        % U: current displacement vector [nDofs×1]
            nElems = length(Elements);
            nz = 48*48*nElems;
            [ii_base, jj_base] = ndgrid(1:48, 1:48);
            ii_base = ii_base(:); jj_base = jj_base(:);
            I = zeros(nz, 1);
            J = zeros(nz, 1);
            V = zeros(nz, 1);
            count = 0;
            for e = 1:nElems
                sctr = SctrMap(e,:);
                u_el = U(sctr);
                Kge = Elements{e}.computeGlobalKg6DOF(u_el);
                range = count + (1:2304);
                I(range) = sctr(ii_base);
                J(range) = sctr(jj_base);
                V(range) = Kge(:);
                count = count + 2304;
            end
            Kg = sparse(I, J, V, nDofs, nDofs);
        end

        function [KT, F_int, TrialHist] = tangent(U, Elements, SctrMap, nDofs)
        % TANGENT  Assemble tangent stiffness, internal force, and trial history.
        % TrialHist: {nElems×1} cell of NewHist structs — NOT committed to elements
            nElems = length(Elements);
            nz = 48*48*nElems;
            [ii_base, jj_base] = ndgrid(1:48, 1:48);
            ii_base = ii_base(:); jj_base = jj_base(:);
            I = zeros(nz, 1);
            J = zeros(nz, 1);
            V = zeros(nz, 1);
            F_int = zeros(nDofs, 1);
            TrialHist = cell(nElems, 1);
            count = 0;
            for e = 1:nElems
                sctr = SctrMap(e,:);
                u_el = U(sctr);
                [KTe, fe, NewHist] = Elements{e}.computeGlobalMatrix6DOF(u_el);
                TrialHist{e} = NewHist;
                F_int(sctr) = F_int(sctr) + fe;
                range = count + (1:2304);
                I(range) = sctr(ii_base);
                J(range) = sctr(jj_base);
                V(range) = KTe(:);
                count = count + 2304;
            end
            KT = sparse(I, J, V, nDofs, nDofs);
        end

        function F_int = internalForce(U, Elements, SctrMap, nDofs)
        % INTERNALFORCE  Compute internal force vector only (no stiffness).
            nElems = length(Elements);
            F_int = zeros(nDofs, 1);
            for e = 1:nElems
                sctr = SctrMap(e,:);
                u_el = U(sctr);
                fe = Elements{e}.computeGlobalForceONLY(u_el);
                F_int(sctr) = F_int(sctr) + fe;
            end
        end

    end
end
