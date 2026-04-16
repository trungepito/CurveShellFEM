function tf = hasMaterialPlastic(obj)
% HASMATERIALPLASTIC  Check if the model uses a plasticity material model.
% Returns true if obj.Model.Material.Type == 'J2Plastic'.

tf = false;
if isprop(obj, 'Model') && isprop(obj.Model, 'Material') && ...
        isfield(obj.Model.Material, 'Type')
    tf = strcmp(obj.Model.Material.Type, 'J2Plastic');
end
end
