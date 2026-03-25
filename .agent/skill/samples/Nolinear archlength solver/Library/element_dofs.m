function [dofs]=element_dofs(e,MESHstruct)

% Get the element dof numbers

dofs=zeros(MESHstruct.nen*MESHstruct.ndof,1);

nodes = MESHstruct.IEN(e,:);

for d=1:2
    dofs(d:2:end) = d+(nodes-1).*2;
end