function [hist] = initialize_history(MESHstruct,EQstruct,MATstruct)
%Initialize history structure for a simple truss

%5 fields are created
field1 = 'si';      %stress
field2 = 'Dti';     %tangent operator
field3 = 'ki';      %hardening parameter
field4 = 'yielded'; %yielding flag
field5 = 'ui';      %global displacement vector

%Initial values for the created fields
%For the first 4 fields the size is set equal to the number of bar elements
%times the number of Gauss points in each element (2) so that the required
%values can be stored for each point of each element
%The tangent operator is initialized with the elastic value while
%everything else is initialized to 0
value1 = zeros(MESHstruct.nel,2);
value2 = ones(MESHstruct.nel,2)*MATstruct.De;
value3 = zeros(MESHstruct.nel,2);
value4 = zeros(MESHstruct.nel,2);

%The displacement vector is initialized with the initial displacement
%vector
value5 = EQstruct.u;

%Creation of the struct
hist = struct(field1,value1,field2,value2,field3,value3,field4,value4,field5,value5);

end