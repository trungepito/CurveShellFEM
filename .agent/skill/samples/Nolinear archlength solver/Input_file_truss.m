%Input file

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Mesh

MESHstruct.ndof = 2; %Number of dofs per node
MESHstruct.nen  = 2; %Number of nodes per element

%Mesh definition
%Define nodes and truss elements through their connectivities
%A function to automatically generate orthogonal trusses is used

nx = 100; %Number of elements in x direction
ny = 5;  %Number of elements in y direction
lx = 50; %Length in x direction
ly = 4;  %Length in y direction

%Call to the truss generation function
[ MESHstruct.COORDS, MESHstruct.IEN ] = orthogonal_truss( nx, ny, lx, ly );

MESHstruct.nnp = size(MESHstruct.COORDS,1);  %Number of nodal points
MESHstruct.nel = size(MESHstruct.IEN,1); %Number of elements
MESHstruct.neq = MESHstruct.nnp*MESHstruct.ndof; %Number of equations

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Material definition

% material properties
E   = 1;                         % Young modulus 
nee = 0.3;                       % poisson ratio
A   = 1;                         % cross section area
sy  = 0.5;                         % yield stress
h   = 0.2;                      % hardening modulus
fy  = @(s,k) abs(s)-(sy + h*k);  % yield function
m   = @(s) sign(s);              % gradient of the yield function
dm  = @(s) 0;                    % gradient of the gradient of the yield function
p   = @(s) 1;                    % hardening function

% assign material parameters to MATstruct
MATstruct.De = E;
MATstruct.nee = nee;
MATstruct.A = A;
MATstruct.fy = fy;
MATstruct.sy = sy;
MATstruct.m = m;
MATstruct.dm = dm;
MATstruct.h = h;
MATstruct.p = p;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Boundary conditions definition

BCstruct.bc_nodes  = sparse(MESHstruct.nnp,1);  % array of nodes with applied BCs
BCstruct.flags1    = sparse(MESHstruct.neq,1);  % array to set B.C flags
BCstruct.flags2    = sparse(MESHstruct.neq,1);  % array to set B.C flags
BCstruct.e_bc      = sparse(MESHstruct.neq,1);  % essential B.C array
BCstruct.n_bc1     = sparse(MESHstruct.neq,1);  % natural B.C array (nodal loads)

%Essential B.C.

%Set of nodes to which BCs are applied (left side of the truss)
ind = find(MESHstruct.COORDS(:,1)==0);

%Set the boundary condition flags of these nodes equal to 1

BCstruct.bc_nodes(ind) = 1;

%Dof numbers of the nodes of set ind

fx = 2*(ind-1)+1;
fy = 2*(ind-1)+2;

%The boundary condition flags corresponding to the dofs of the selected
%nodes are set to 1
BCstruct.flags1(fx) = 1;
BCstruct.flags1(fy) = 1;

%The values of the displacements at the selected nodes are set to zero
BCstruct.e_bc(fx) = 0;
BCstruct.e_bc(fy) = 0;

%Natural B.C.

%Nodal loads

%Set of nodes to which nodal loads are applied (top right point of the truss)
% ind = find((MESHstruct.COORDS(:,1)>0.999*lx) & (MESHstruct.COORDS(:,2)>0.999*ly));
ind = 105;

%Dof numbers of the nodes of set ind

fx = 2*(ind-1)+1;
fy = 2*(ind-1)+2;

%The nodal oad flags corresponding to the dofs of the selected nodes are
%set to 1

BCstruct.flags2(fx) = 1;
BCstruct.flags2(fy) = 1;

%Value of the applied load

p=10;

%The value of the nodal load at the y direction is set equal to p

BCstruct.n_bc1(fx) = 0;
BCstruct.n_bc1(fy) = p;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Initialization of the vectors and matrices needed for the equilibrium
%equations

EQstruct.lambda = 0;                       % initialize load factor
EQstruct.R = zeros(MESHstruct.neq,1);      % initialize residual vector
EQstruct.f = zeros(MESHstruct.neq,1);      % initialize force vector
EQstruct.u = zeros(MESHstruct.neq,1);      % initialize displacement vector
EQstruct.du = zeros(MESHstruct.neq,1);     % initialize displacement increment vector
EQstruct.K = sparse(MESHstruct.neq,MESHstruct.neq);        % initialize tangent matrix

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Definition of solver parameters

%Constraint to be used for the arc length solver
%First case: load control
SOLstruct.constraint = @load_control;
SOLstruct.predictor = 0; %Flag for using a predictor
% SOLstruct.arc_length = [0.025*ones(14,1); -0.025*ones(14,1)]; %Values of the 
%load factor for load control
SOLstruct.arc_length = [0.05*ones(14,1); -0.05*ones(14,1)]; %Values of the 

%Second case: displacement control
%The y displacement of the top right point of the truss
% SOLstruct.constraint = @(u, l, u0, l0, dup, dlp, si) displ_control(u, l, u0, l0, dup, dlp, si, 2*ind);
% SOLstruct.predictor = 0; %Flag for using a predictor
% SOLstruct.arc_length = [10*ones(20,1); -10*ones(20,1)]; %Values of the
%controlled displacement

%Third case: Riks method
% SOLstruct.constraint = @Riks;
% SOLstruct.predictor = 1; %Flag for using a predictor
% SOLstruct.arc_length = 25*ones(60,1); %Values of the arc length

SOLstruct.max_trials = 4; % Maximum number of unseccessful solutions with
                          % the arc length solver allowed
SOLstruct.tol = 1e-3;     %Tolerance used for the solution
SOLstruct.maxit =20;      %Maximum number of iterations for the solution

%Dof number of the displacement to be monitored (the displacement plotted 
%in the load deflection curve will refer to that dof)
SOLstruct.monitored_displ = 2*ind;

%Number of solution steps
SOLstruct.steps = length(SOLstruct.arc_length);
%Vector to store load factor at each load step
SOLstruct.lambda_i = [0; zeros(length(SOLstruct.arc_length),1)];
%Vector to store displacements at each step
SOLstruct.u_i = [0; zeros(length(SOLstruct.arc_length),1)];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Clear all variables except the structs containing the model data
clearvars -except MESHstruct MATstruct BCstruct EQstruct SOLstruct