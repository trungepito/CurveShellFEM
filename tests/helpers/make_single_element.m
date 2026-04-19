function [coords, normals] = make_single_element(varargin)
% MAKE_SINGLE_ELEMENT  Return coords and normals for one flat 8-node element.
%
% Default: 1m x 1m flat element in the XY plane.
% Optional name-value:
%   'Lx', Lx   — x side length  (default 1.0)
%   'Ly', Ly   — y side length  (default 1.0)
%   'distort', tf — apply small distortion to interior nodes (default false)
%
% Node ordering: corners 1-4 (CCW from origin), midsides 5-8.
%   1=(-1,-1), 2=(1,-1), 3=(1,1), 4=(-1,1)
%   5=(0,-1),  6=(1,0),  7=(0,1), 8=(-1,0)  [in physical coords]

p = inputParser();
p.addParameter('Lx', 1.0);
p.addParameter('Ly', 1.0);
p.addParameter('distort', false);
p.parse(varargin{:});
Lx = p.Results.Lx;
Ly = p.Results.Ly;

% Physical coordinates of 8 nodes (XY plane, z=0)
coords = [
    0,    0,    0;    % node 1
    Lx,   0,    0;    % node 2
    Lx,   Ly,   0;    % node 3
    0,    Ly,   0;    % node 4
    Lx/2, 0,    0;    % node 5 (midside 1-2)
    Lx,   Ly/2, 0;    % node 6 (midside 2-3)
    Lx/2, Ly,   0;    % node 7 (midside 3-4)
    0,    Ly/2, 0;    % node 8 (midside 4-1)
];

if p.Results.distort
    % Perturb midside nodes slightly to create non-rectangular element
    coords(5, 1) = coords(5, 1) + 0.05 * Lx;
    coords(8, 2) = coords(8, 2) + 0.05 * Ly;
end

% All normals point in +Z for flat element
normals = repmat([0, 0, 1], 8, 1);
end
