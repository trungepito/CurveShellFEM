function createPlate(obj, origin, Lx, Ly)
% Origin: [x,y,z], Lx/Ly: Dimensions
p1 = obj.addKeypoint(origin(1),    origin(2),    origin(3));
p2 = obj.addKeypoint(origin(1)+Lx, origin(2),    origin(3));
p3 = obj.addKeypoint(origin(1)+Lx, origin(2)+Ly, origin(3));
p4 = obj.addKeypoint(origin(1),    origin(2)+Ly, origin(3));

l1 = obj.addLine(p1, p2, 'straight');
l2 = obj.addLine(p2, p3, 'straight');
l3 = obj.addLine(p3, p4, 'straight'); % Order needs to be loop
l4 = obj.addLine(p4, p1, 'straight');

% For Coons patch, Top (l3) and Left (l4) logic is specific in mesher
% Standard Loop: Bottom, Right, Top(rev), Left(rev)
obj.addPatch(l1, l2, l3, l4);
end