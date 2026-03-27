function [g, h, s] = displ_control(u, l, u0, l0, dup, dlp, si, dof)

% Displacement control constraint function
% Output arguments
% g   -> constraint function
% h   -> gradient with respect to the displacements
% s   -> gradient with respect to the load factor
% Input arguments
% u   -> displacements at the current increment
% l   -> load factor at the current increment
% u0  -> displacements at the beginning of the load step
% l0  -> load factor at the beginning of the load step
% dup -> displacement increment of the predictor step
% dlp -> load factor increment of the predictor step
% si  -> arc length

% The target displacement for this step is equal to the displacement at the
% beginning of the step plus the arc length which in this case is the
% displacement increment. Also in this case the displacement component of
% interest is component 6
u_ = u0(dof)+si;

g = u(dof)-u_;

h = zeros(length(u),1);
h(dof) = 1;

s = 0;