function createCylinderPanel(obj, R, H, angleStart, angleEnd)
% Aligned with Z-axis
x1 = R*cos(angleStart); y1 = R*sin(angleStart);
x2 = R*cos(angleEnd);   y2 = R*sin(angleEnd);

p1 = obj.addKeypoint(x1, y1, 0);
p2 = obj.addKeypoint(x2, y2, 0);
p3 = obj.addKeypoint(x2, y2, H);
p4 = obj.addKeypoint(x1, y1, H);

pc = obj.addKeypoint(0,0,0); % Center for arcs
pc_top = obj.addKeypoint(0,0,H);

l_bot = obj.addLine(p1, p2, 'arc', pc);
l_rgt = obj.addLine(p2, p3, 'straight');
l_top = obj.addLine(p3, p4, 'arc', pc_top); % Note: Mesher flips top
l_lft = obj.addLine(p4, p1, 'straight');    % Note: Mesher flips left

obj.addPatch(l_bot, l_rgt, l_top, l_lft);
end