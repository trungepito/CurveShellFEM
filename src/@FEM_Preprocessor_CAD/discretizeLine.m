function pts = discretizeLine(obj, lineID, nPts)
% DISCRETIZELINE  Generate points along a geometric line entity.
%
% Supports:
%   'straight' - Linear interpolation between P1 and P2.
%   'arc'      - Circular arc in 3D (v3.0 fix: full 3D sweep, not XY-only).
%
% v3.0 Fix (TD-05): Arc interpolation now uses a proper 3D frame
% defined by the arc plane normal, removing the XY-plane assumption
% that produced incorrect node positions for non-planar arcs.

L  = obj.GeoLines{lineID};
P1 = obj.GeoPoints(L.p1, :);
P2 = obj.GeoPoints(L.p2, :);

switch L.type

    case 'straight'
        s   = linspace(0, 1, nPts)';
        pts = P1 + s * (P2 - P1);

    case 'arc'
        % Centre of the arc (required field in GeoLine struct)
        C = obj.GeoPoints(L.center, :);

        R1  = P1 - C;                      % Radius vector to start
        R2  = P2 - C;                      % Radius vector to end
        R   = norm(R1);                    % Arc radius (assert == norm(R2))

        % Build a 2D in-plane orthonormal frame {e1, e2}
        e1  = R1 / R;                      % Points toward P1
        n   = cross(R1, R2);               % Arc plane normal
        if norm(n) < eps * R^2
            % Degenerate: P1, C, P2 collinear — fall back to straight line
            warning('FEM_Preprocessor_CAD:discretizeLine', ...
                'Arc lineID=%d is degenerate (P1, C, P2 collinear). Using straight line.', lineID);
            s   = linspace(0, 1, nPts)';
            pts = P1 + s * (P2 - P1);
            return;
        end
        e2  = cross(n / norm(n), e1);      % In-plane, perpendicular to e1

        % Sweep angle from P1 to P2 in the e1-e2 frame
        phi2 = atan2(dot(R2, e2), dot(R2, e1));
        if phi2 < 0, phi2 = phi2 + 2*pi; end  % Enforce CCW convention

        theta = linspace(0, phi2, nPts)';
        pts   = C + R * (cos(theta) .* e1 + sin(theta) .* e2);

    otherwise
        error('FEM_Preprocessor_CAD:discretizeLine', ...
            'Unknown line type ''%s'' for lineID=%d.', L.type, lineID);
end
end