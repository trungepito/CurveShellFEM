function [Ke,Re,hist] = residual_tangent_matrix(e,EQstruct,MESHstruct,MATstruct,dofs, hist,nri)
%Evaluate element tangent stiffness and residual

A  = MATstruct.A;                    %Cross sectional area
IEN      = MESHstruct.IEN;           %Element connectivity
due = EQstruct.du(dofs);             %Element incremental displacements
enodes = IEN(e,:);                   %Element nodes
Ce  = MESHstruct.COORDS(enodes,:);   %Element node coordinates
dx  = Ce(2,:)-Ce(1,:);               %Vector along the element
l   = norm(dx);                      %Element length
phi = atan2(dx(2),dx(1));            %Element angle

%Transformation matrix
T = [ cos(phi)  sin(phi)  0         0
     -sin(phi)  cos(phi)  0         0
      0         0         cos(phi)  sin(phi)
      0         0        -sin(phi)  cos(phi)];


%Displacement increment in the local coordinante system of the bar
dul = T*due;
  
%Gauss point weights and coordinates
ngp=2;
wgp = [1 1];
ksigp = [-1/sqrt(3) 1/sqrt(3)];

%Jacobian determinant
detJ = l/2;

%Shape function derivatives
Bf=@(ksi) [-1 0 1 0];

%Initialize local tangent stiffness matrix and residual
Kl = zeros(4,4);
Rl = zeros(4,1);

%Numerical integration loop
for i = 1:ngp       
    [B]   = Bf(ksigp(i));     % derivative of the shape functions
    
    dei = B*dul;              %strain increment at Gauss point
    
    %Retrieve the stress, tangent stiffness hardening parameter and
    %yielding flag for this element and Gauss point at the previous
    %increment
    s0 = hist.si(e,i);
    Dt0 = hist.Dti(e,i);
    k0 = hist.ki(e,i);
    y = hist.yielded(e,i);
    
    %Run the return mapping algorithm
    [ si, ki, Dti, y ] = return_mapping( dei, s0, k0, Dt0, MATstruct,e,ngp,nri);
     
  
    %Update tangent stiffness matrix and residual
    Kl = Kl + wgp(i)*B'*Dti*A*B*detJ;
    Rl = Rl + wgp(i)*B'*si*A*detJ;
    
    %Update history variables
    hist.si(e,i) = si;
    hist.Dti(e,i) = Dti;
    hist.ki(e,i) = ki;
    %If yielding flag is raised set the corresponding history variable to 1
    if (y==1)
        hist.yielded(e,i) = y;
    end
end

%Transform tangent stiffness matrix and residual to global system
Ke = T'*Kl*T;
Re = T'*Rl;

end