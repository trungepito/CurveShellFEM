%Main script
clear all; close all; clc;
addpath(genpath(pwd))
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Preprocessing
%Input of data from the input file
% Input_file_bar;
Input_file_truss

%Plot undeformed mesh
scale = 0; %Scale used for the displacements, set to 0 for undeformed struccture

% Parameter ranging from 0 to 1 to specify the transparency of the bars
% in the plot.
transparency = 0.5;

%Function to plot the deformed mesh
plotmesh_deformed(MESHstruct,EQstruct,scale,transparency);

%Initialize struct to store history variables
[hist] = initialize_history(MESHstruct,EQstruct,MATstruct);

%Function handle to the assembly procedure
f = @(u,l,hist,nri)Assemble(EQstruct,MESHstruct,MATstruct,BCstruct,u,l,hist,nri);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Solution
nri=0;

%Loop over the solution steps
for i=1:SOLstruct.steps        
    converged = 0; % Set convergence flag to false
    
    %Displacement vector and load factor at the beginning of the step
    u0 = EQstruct.u;
    l0 = EQstruct.lambda;
    
    % Initialize counter to count number of trials
    c = 1;
    
    %Store history structure before the solution step (this can be used in 
    %case the step fails)
    hist0=hist;
    % Call the arc length solver function until it converges
    while ((~converged)&&(c<=SOLstruct.max_trials))
        %Solution using the general arc length algorithm
        %The hist struct is passed to the arc length solver so that history
        %parameters can be updating during the iterations. The struct is
        %returned by the solver to be used in the next steps
        [EQstruct.u, EQstruct.lambda, hist, converged,nri] = arc_length_solver(f, SOLstruct.constraint,...
            u0 , l0, hist, SOLstruct.arc_length(i), SOLstruct.predictor,...
            SOLstruct.tol,SOLstruct.maxit,nri);
        
        c = c + 1; % Increase counter
        
        % If the solver has not converged and the maximum number of trials
        % has not been reached, reduce the arc length to half the initial
        % value
        if ((~converged)&&(c<=SOLstruct.max_trials))
            fprintf(1,'Reducing arc length from %d to  %d \n',SOLstruct.arc_length(i),0.5*SOLstruct.arc_length(i));
            SOLstruct.arc_length(i) = 0.5*SOLstruct.arc_length(i);
            hist = hist0;
        end
    end
    
    % Print a message in case the step did not converge
    if (~converged)
        fprintf(1,'Step did not converge after %d trials\n',c-1);
        break;
    end
    
    %Update solution parameters for output
    SOLstruct.u_i(i+1)=EQstruct.u(SOLstruct.monitored_displ);
    SOLstruct.lambda_i(i+1)=EQstruct.lambda;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Postprocessing

%Plot deformed mesh
%Find largest and smallest coordinate values to set scale relative to the
%structure size
dx = max(MESHstruct.COORDS(:,1))-min(MESHstruct.COORDS(:,1));
dy = max(MESHstruct.COORDS(:,1))-min(MESHstruct.COORDS(:,1));
lmax = max(dx,dy);

umax = max(abs(EQstruct.u));

scale = (lmax/umax)*1e-1; %scale used in the plot
figure % A new figure is created
%The hist struct is passed to the plotting function to plot plastic
%elements
plotmesh_deformed(MESHstruct,EQstruct,scale,transparency, hist);
title ('Plastified Elements Plot')

% Plot load deflection curve
figure
plot(SOLstruct.u_i,SOLstruct.lambda_i);grid on
ylabel('$\lambda$','interpreter','latex')
xlabel('Displacement')
title('Nonlinear Load displacement Curve')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Clear all variables except the structs containing the model data
clearvars -except MESHstruct MATstruct BCstruct EQstruct SOLstruct