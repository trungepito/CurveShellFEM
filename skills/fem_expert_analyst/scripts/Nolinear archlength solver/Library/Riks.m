function [g, h, s] = Riks(u, l, u0, l0, dup, dlp, si)

% Constraint function for the Riks method
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

%Solution at the end of the predictor
u1 = u0+dlp*dup;
l1 = l0+dlp;

g = dup'*(u-u1) + dlp*(l-l1);
h = dup;
s = dlp;