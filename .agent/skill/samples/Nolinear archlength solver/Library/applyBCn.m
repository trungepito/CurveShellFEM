function [EQstruct]=applyBCn(EQstruct,BCstruct)

%Apply nodal loads

EQstruct.f = zeros(length(BCstruct.flags2),1);

dofs = find(BCstruct.flags2==1);

EQstruct.f(dofs)=BCstruct.n_bc1(dofs);