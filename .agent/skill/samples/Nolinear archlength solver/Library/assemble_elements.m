function [EQstruct, HISTstruct]=assemble_elements(EQstruct,MESHstruct,MATstruct,HISTstruct,nri)

%Function to assemble the tangent stiffness matrix and residual vector

EQstruct.K = sparse(MESHstruct.neq,MESHstruct.neq); %initialize stiffness matrix
EQstruct.R = zeros(MESHstruct.neq,1);      % initialize residual vector

for e=1:MESHstruct.nel %Loop over the elements
    
    [dofs]=element_dofs(e,MESHstruct); %Dof numbers of the element nodes
    
    %Stiffness matrix and residual vector for element e
    [Ke,Re, HISTstruct] = residual_tangent_matrix(e,EQstruct,MESHstruct,MATstruct,dofs,HISTstruct,nri);
     
    %Add element tangent stiffness matrix and residual vector to the
    %corresponding global quantities
    EQstruct.K(dofs,dofs)=EQstruct.K(dofs,dofs)+Ke;
    EQstruct.R(dofs)= EQstruct.R(dofs)+Re;
end