function [g, h, s] = load_control(u, l, u0, l0, dup, dlp, si)
% Load control constraint function
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

% The target load factor for this step is equal to the load factor at the
% beginning of the step plus the arc length which in this case is the
% displacement increment
l_ = l0+si;

g = l-l_;

h = zeros(length(u),1);

s = 1;