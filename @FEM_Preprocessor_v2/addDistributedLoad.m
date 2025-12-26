function addDistributedLoad(obj, elemIDs, loadVector,tag)
% Uniform Vector Load over Area (e.g., Gravity or Wind)
% loadVector: [Fx, Fy, Fz] (Force/Area)
% Creates Consistent Nodal Loads

loadFunc = @(r,t,z) loadVector(:); % Constant function
% Note: We reuse the integration logic, but passed as cartesian
% We need a generic integrator.
obj.integrateSurfaceLoad(elemIDs, loadFunc, 'cartesian',tag);
end