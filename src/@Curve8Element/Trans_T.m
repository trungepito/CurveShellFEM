function T_hybrid=Trans_T(obj)
% define the transformation matrix to transform the [U V W rotx roty rotz]
% to [U V W ROTX ROTY ROTZ] for any element
C=repmat({speye(3)},1,16);
% T_hybrid = zeros(48, 48);
for n = 1:8
    % idx = (n-1)*6 + (1:6);
    % Get Nodal Basis Vectors (v1, v2, v3)
    % (Use exactly the same logic as inside computeStiffnessMatrix)
    V3 = obj.Normals(n,:); V3=V3/norm(V3);
    if abs(V3(2)) < 0.9, V1=cross([0,1,0],V3); else, V1=cross([1,0,0],V3); end
    V1=V1/norm(V1); V2=cross(V3,V1);
    % Rotation Matrix (Global to Local)
    R = [V1; V2; V3];

    % The Identity Matrix for translations (DO NOT ROTATE U,V,W)
    % The R Matrix for rotation
    % T_hybrid(idx, idx) = blkdiag(eye(3), R);
    C{2*n}=R;
end
T_hybrid=blkdiag(C{:});