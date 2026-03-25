function plotmesh_deformed(MESHstruct,EQstruct,scale,i,varargin)

nel  = MESHstruct.nel;
COORD = MESHstruct.COORDS; 
x = COORD(:,1);
y = COORD(:,2);
ux = EQstruct.u(1:2:end);
uy = EQstruct.u(2:2:end);

if (nargin==5)
    yielded = varargin{1}.yielded;
end

for e = 1:nel
    enodes = MESHstruct.IEN(e,:);
    
    if (nargin==5)
        if ((yielded(e,1)==1)||(yielded(e,2)==1))
            color = 'r';
        else
            color = 'k';
        end
        plot(x(enodes)+scale*ux(enodes),y(enodes)+scale*uy(enodes),'-o','Color',color,'LineWidth',1.5,'MarkerEdgeColor','k','MarkerFaceColor','k','MarkerSize',6);
        hold on;
    else
        plot(x(enodes)+scale*ux(enodes),y(enodes)+scale*uy(enodes),'-o','Color',[i i i],'LineWidth',1.5,'MarkerEdgeColor',[i i i],'MarkerFaceColor',[i i i],'MarkerSize',6);
        hold on; 
    end
end

axis equal;
title ('Problem Structure')