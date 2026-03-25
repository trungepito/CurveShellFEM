function [R, K, f, HISTstruct] = Assemble(EQstruct,MESHstruct,MATstruct,BCstruct,u,l,HISTstruct,nri)

%Update EQstruct
EQstruct.u=u; %Displacement vector
EQstruct.lambda=l; %Load factor
EQstruct.du = u - HISTstruct.ui; %Displacement increment (difference of 
%displacement vector with the previous displacement vector, stored in HISTstruct)

%Assembly of tangent stiffness matrix and residual vector

[EQstruct,HISTstruct]=assemble_elements(EQstruct,MESHstruct,MATstruct,HISTstruct,nri);

%Application of Neumann B.C.

[EQstruct]=applyBCn(EQstruct,BCstruct);

%Application of Dirichlet B.C.

[EQstruct]=applyBCd(EQstruct,BCstruct);

%Subtract external loads from the residual vector

EQstruct.R = EQstruct.R - EQstruct.lambda*EQstruct.f;

%Update the displacement vector stored in HISTstruct
HISTstruct.ui = u;

%Return the updated residual, tangent stiffness and external loads
R = EQstruct.R;
K = EQstruct.K;
f = EQstruct.f;