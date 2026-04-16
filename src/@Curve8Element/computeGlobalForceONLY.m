function fe_global = computeGlobalForceONLY(obj, u_el)
% COMPUTEGLOBALFORCEONLY - Efficient internal force calculation for line search.
% u_el: 48x1 global element displacements
%
% This is a performance wrapper around the validated computeGlobalMatrix6DOF.
% It discards the tangent stiffness calculation to save assembly time.

    [~, fe_global, ~] = obj.computeGlobalMatrix6DOF(u_el);
    
end
