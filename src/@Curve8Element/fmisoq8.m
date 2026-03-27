function [fun, der] = fmisoq8(xi, eta)
% FMISOQ8 - Shape functions and derivatives for 8-node serendipity quad.
% Supports vectorized xi, eta inputs.
% fun: [nGP x 8]
% der: [2 x 8 x nGP]

xi = xi(:); eta = eta(:);
nGP = length(xi);

etam = (1-eta); etap = (1+eta);
xim = (1-xi);   xip = (1+xi);

fun = zeros(nGP, 8);
fun(:,1) = -0.25 * xim .* etam .* (1 + xi + eta);
fun(:,5) =  0.5  * (1 - xi.^2) .* etam;
fun(:,2) = -0.25 * xip .* etam .* (1 - xi + eta);
fun(:,6) =  0.5  * xip .* (1 - eta.^2);
fun(:,3) = -0.25 * xip .* etap .* (1 - xi - eta);
fun(:,7) =  0.5  * (1 - xi.^2) .* etap;
fun(:,4) = -0.25 * xim .* etap .* (1 + xi - eta);
fun(:,8) =  0.5  * xim .* (1 - eta.^2);

if nargout > 1
    der = zeros(2, 8, nGP);
    % dN/dxi
    der(1,1,:) = 0.25 * etam .* (2*xi + eta);
    der(1,5,:) = -1 * etam .* xi;
    der(1,2,:) = 0.25 * etam .* (2*xi - eta);
    der(1,6,:) = 0.5 * (1 - eta.^2);
    der(1,3,:) = 0.25 * etap .* (2*xi + eta);
    der(1,7,:) = -1 * etap .* xi;
    der(1,4,:) = 0.25 * etap .* (2*xi - eta);
    der(1,8,:) = -0.5 * (1 - eta.^2);
    
    % dN/deta
    der(2,1,:) = 0.25 * xim .* (2*eta + xi);
    der(2,5,:) = -0.5 * (1 - xi.^2);
    der(2,2,:) = -0.25 * xip .* (xi - 2*eta);
    der(2,6,:) = -1 * xip .* eta;
    der(2,3,:) = 0.25 * xip .* (xi + 2*eta);
    der(2,7,:) = 0.5 * (1 - xi.^2);
    der(2,4,:) = -0.25 * xim .* (xi - 2*eta);
    der(2,8,:) = -1 * xim .* eta;
end
end
