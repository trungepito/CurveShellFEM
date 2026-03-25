function [EQstruct]=applyBCd(EQstruct,BCstruct)

%Apply essential BC

neq=length(EQstruct.R);

for n=1:length(EQstruct.R)
   if (BCstruct.flags1(n) == 1)
         EQstruct.R = EQstruct.R - EQstruct.K(:,n)*BCstruct.e_bc(n);                  
         EQstruct.K(n,:) = zeros(1,neq);
         EQstruct.K(:,n) = zeros(neq,1);
         EQstruct.K(n,n) = 1.0;
         EQstruct.R(n)   = BCstruct.e_bc(n);
   end
end

end