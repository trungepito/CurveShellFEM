function createIBeam(obj, H, W, L, numseg,meshz)
% Creates 3 Patches: Bottom Flange, Web, Top Flange
% Extruded along Z (Length L)
if nargin<=4
    numseg=1;
    meshz=[4,10];
end
coord=[0 -W/2 -H/2;
    0  0   -H/2;
    0  W/2 -H/2;
    0  -W/2 H/2;
    0  0    H/2;
    0  W/2  H/2];
%Flanges

for iseg=1:numseg
    for i=1:5
        if i==3
            continue;
        end
        p1=obj.addKeypoint(coord(i,:)); p2=obj.addKeypoint(coord(i+1,:));
        p3=obj.addKeypoint(coord(i+1,:)+[L,0,0]);  p4=obj.addKeypoint(coord(i,:)+[L,0,0]);
        l1=obj.addLine(p1,p2,'straight'); l2=obj.addLine(p2,p3,'straight');
        l3=obj.addLine(p3,p4,'straight'); l4=obj.addLine(p4,p1,'straight');
        pid=obj.addPatch(l1,l2,l3,l4);
        obj.meshQuadPatch(pid, meshz(1), meshz(2));
    end
    % Web: from [0, -H/2, 0] to [0, H/2, L]
    p1=obj.addKeypoint(coord(2,:)); p2=obj.addKeypoint(coord(5,:));
    p3=obj.addKeypoint(coord(5,:)+[L,0,0]);  p4=obj.addKeypoint(coord(2,:)+[L,0,0]);
    l1=obj.addLine(p1,p2,'straight'); l2=obj.addLine(p2,p3,'straight');
    l3=obj.addLine(p3,p4,'straight'); l4=obj.addLine(p4,p1,'straight');
    pid=obj.addPatch(l1,l2,l3,l4);
    obj.meshQuadPatch(pid, meshz(1), meshz(2));
    coord=coord+[L,0,0];
end
obj.fuseNodes(1e-5);
obj.computeNormals();
end