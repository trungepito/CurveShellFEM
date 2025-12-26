function [g_points,g_weights]=Gauss_p(npoint)
if npoint < 1 || npoint > 5
    error('npoint must be 1, 2, 3, 4 or 5');
end
switch npoint
    case 1
        g_points = 0;
        g_weights = 2;
    case 2
        g_points = [-1/sqrt(3), 1/sqrt(3)];
        g_weights = [1, 1];
    case 3
        g_points = [-sqrt(3/5), 0, sqrt(3/5)];
        g_weights = [5/9, 8/9, 5/9];
    case 4
        g_points = [-sqrt(3/7-2/7*(sqrt(6/5))), sqrt(3/7-2/7*(sqrt(6/5))),...
            -sqrt(3/7+2/7*(sqrt(6/5))), sqrt(3/7+2/7*(sqrt(6/5)))];
        g_weights = [(18+sqrt(30))/36, (18+sqrt(30))/36, (18-sqrt(30))/36, (18-sqrt(30))/36];
    case 5
        g_weights=[(322+13*sqrt(70))/900, (322+13*sqrt(70))/900, 128/225,...
            (322-13*sqrt(70))/900,(322-13*sqrt(70))/900];
        g_points=[-1/3*sqrt(5-2*sqrt(10/7)), 1/3*sqrt(5-2*sqrt(10/7)),0,...
            -1/3*sqrt(5+2*sqrt(10/7)), 1/3*sqrt(5+2*sqrt(10/7))];
    otherwise
        error('npoint must be 1, 2, 3, 4, or 5');
end

end