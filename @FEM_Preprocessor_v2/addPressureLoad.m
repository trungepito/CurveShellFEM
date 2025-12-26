function addPressureLoad(obj, elemIDs, magnitude,tag)
% Pressure Perpendicular to Shell Surface
% magnitude: Scalar (Positive = Outward/Normal direction)

% We define a special function handle that returns P in Normal Dir
% But integration routine needs specific logic for 'normal' type.

loadFunc = @(n_vec) magnitude * n_vec;
obj.integrateSurfaceLoad(elemIDs, loadFunc, 'normal',tag);
end