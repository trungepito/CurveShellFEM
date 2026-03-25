function [u, l, hist, converged, nri] = arc_length_solver(func, constraint, u0, l0, hist,...
                             arc_length, predictor, tol, maxit,nri)

%Arc length solver
%Output arguments
%u         -> Displacement vector at the end of the step
%l         -> Load factor at the end of the step
%hist      -> Structure containing history variables
%converged -> Convergence flag, assumes a value true if the convergence
%             criterion is satisfied and false otherwise

%Input arguments
%func      -> Function handle for evaluating the residual, tangent stiffness matrix
%             and external force vector. It should take as input arduments
%             the displacement vector, load factor and history variables at the current
%             increment and return the residual, tangent stiffness matrix,
%             external force vector and history variables: 
%             [R, Kt, fext] = func(u,l,hist)
%constaint -> Function handle for evaluating the constraint function as
%             well as its gradients with respect to the displacements and
%             load factor. It should take as input arguments the
%             displacement and load factor at the current increment,
%             displacement and load factor at the beginning of the step,
%             displacement and load factor increments of the predictor and
%             arc length and return the constraint function and its
%             gradients with respect to the displacements and load factor:
%             [g, h, s]= constraint(u, l, u0, l0, dup, dlp, si)
%u0        -> Displacement vector at the begining of the step
%l0        -> load factor at the beginning of the step
%hist      -> Structure containing history variables
%arc_length-> The arc length at the current step
%predictor -> A flag to specify whether a predictor step is needed
%tol       -> Tolerance used for the Newton-Raphson iterations
%maxit     -> Maximum number of iterations allowed

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%Initialization%%%%%%%%%%%

%The displacement vector and load factor are initialized to their values at
%the begining of the step
u = u0;
l = l0;

% Evaluate residual, tangent stiffness and external loads
[R, Kt, fext, hist] = func(u,l,hist,nri);

% The value of the norm of the external loads is
% stored. This value will be used to check convergence
f_norm=norm(fext);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%Predictor step%%%%%%%%%%%

%The displacement and load factor increment of the predictor step are
%initialized
dup = zeros(length(u),1);
dlp = 0;


if (predictor==1) %Check whether a predictor step is required

    dup = Kt\fext; % Predictor displacement increment

    k_0 = fext'*dup/(dup'*dup); % Current stiffness parameter

    % The sign of the load factor increment is changed according to the
    % sign of the current stiffness parameter
    if (k_0)>=0
        dlp = arc_length/norm(dup);
    else
        dlp = -arc_length/norm(dup);
    end

    % Update displacement vector and load factor using the values obtained
    % from the predictor
    u = u + dlp*dup;
    l = l + dlp;
    
    [R, Kt,~,~] = func(u,l,hist);% Update residual and tangent stiffness
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%Solution%%%%%%%%%%%%%%

%Begin Newton-Raphson loop
for i=1:maxit
    nri = nri + 1;
    %Evaluation of the constraint and its derivatives with respect to u and l
    [g, h, s] = constraint(u, l, u0, l0, dup, dlp, arc_length);

    %Solution of the two linear systems

    du_I = Kt\fext;

    du_II = -Kt\R;

    %Load and displacement increment

    dl = - (g+h'*du_II)/(s+h'*du_I);

    du = dl*du_I+du_II;

    % Update of loads and displacements

    l = l + dl;
    u = u + du;
    
    % Evaluate residual, and tangent stiffness
    [R, Kt,~,hist] = func(u,l,hist,nri);
    
    Rnorm=norm(R); %Residual norm
    
    %Convergence check
    if (Rnorm <= tol*f_norm)
        %If the convergence criterion is satisfied print the number of required
        %iterations and break the loop
        fprintf(1,'Solution converged after %d iterations. Residual norm  %d \n',i,Rnorm);
        converged = 1; % Set convergence flag true
        break
    end
end

if i==maxit
    %If the maximum number of iterations has been reached print a message
    fprintf(1,'Solution did not converge after %d iterations. Residual norm  %d \n',maxit,Rnorm);
    converged = 0;% Set convergence flag true
end