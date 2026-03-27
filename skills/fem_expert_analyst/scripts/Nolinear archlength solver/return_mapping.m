function [ si, ki, Dti, y, err ] = return_mapping( de, s0, k0, Dt0, MATstruct,flag1, flag2,nri)
%Return mapping algorithm
%Output arguments
%si        -> Stress at the end of the increment
%ki        -> Hardening parameter at the end of the increment
%Dti       -> Consistent tangent operator at the end of the increment
%y         -> Yielding flag, will assume a value of 1 if yielding occurs
%err       -> Error flag, assumes a value of 1 if the algorithm does not
%             converge

%Input arguments
%de        -> Strain increment
%s0        -> Stress at the beginning of the increment
%k0        -> Hardening parameter at the beginning of the increment
%Dt0       -> Tangent operator at the begining of the increment
%MATstruct -> A struct containing all required material parameters, such as
%             elastic tangent operator, yielding function etc.

%Read parameters from MAT struct
De  = MATstruct.De;   %Elastic tangent operator
sy  = MATstruct.sy;   %Yielding stress
fy  = MATstruct.fy;   %Yield function
mf  = MATstruct.m;    %Yield function gradient
dmf = MATstruct.dm;   %Gradient of the yield function gradient
pf  = MATstruct.p;    %Hardening function
h   = MATstruct.h;    %Hardening modulus

tol=1e-4*sy; %Tolerance for the yielding function

%Elastic predictor
se = s0 + De*de;

%Check for yielding
if (fy(se, k0)<=tol)
    %If the yield criterion is not violated set the stress equal to the
    %elastic predictor, the tangent modulus equal to the elastic one and
    %the hardening parameter equal to its initial value. The error and 
    %yielding flags are set to 0
    si  = se;
    Dti = De;
    ki  = k0;
    y   = 0;
    err = 0;
else
    %If the yield criterion is violated start the return mapping algorithm
    
    nc = size(s0,1); %Number of stress components (a variable number is possible)
    I = eye(nc);     %Unit matrix the size of the number of components
    
    si = se;         %Stress is set equal to the elastic predictor
%     figure(100*flag1+flag2)
%     scatter(nri,si,'d','filled','r','DisplayName','Arc-length Initiation');hold on;grid on   
        
    ki  = k0;        %Hardeing parameter is set equal to its initial value
    dli = 0;         %Plastic multiplier is set to 0
    
    m = mf(si);      %Evaluate yield function gradient
    dm = dmf(si);    %Evaluate gradient of yield function gradient
    p = pf(si);      %Evaluate hardening function
    
    es = si - se + De*m*dli; %Stress residual
    ek = ki - k0 - p*dli;    %Hardening residual
    ef = abs(fy(si,ki));     %Yield function residual
    
    e = [es; ek; ef];        %Total residual
    
    e_norm = norm(e);        %Residual norm
    
    maxit = 10;              %Maximum allowed nu,ber of iterations
    
    c=0;                     %Iteration counter
    
    %Newton Raphson loop
    %The norm of the residual and the number of iterations are used as
    %stopping criteria
    while ((e_norm>=tol)&&(c<maxit))
        %Jacobian matrix
        % |des/ds  des/dk des/dl|
        % |dek/ds  dek/dk dek/dl|
        % |def/ds  def/dk def/dl|
        %It is assumed that:
        %des/dk = 0
        %dek/ds = 0
        Jac = [I + De*dm*dli  zeros(nc,1)  De*m
               zeros(1,nc)       1         -p
               m'               -h          0];
        
        %Vector containing incremental values for the stress, hardening
        %parameter and plastic multiplier
        dx = Jac\e;
        
              
        %Update stress, hardening parameter and plastic multiplier
        si  = si - dx(1);     
        ki  = ki - dx(2);
        dli = dli - dx(3);
        
%         scatter(nri,si,'o','b','DisplayName','Return Mapping Step');hold on;grid on

        ylabel('Yield Stress');
        xlabel('Arc-Length Calculation Step'); 
        title(['Element = ', num2str(flag1), ' - Gauss Point = ',num2str(flag2)])

        %Evaluate yield function gradient, gradient of the yield function
        %gradient and hardening function
        m  = mf(si);
        dm = dmf(si);
        p  = pf(si);

        %Update stress, hardening and plastic multiplier residual
        es = si - se + De*m*dli;      
        ek = ki - k0 - p*dli;
        ef = abs(fy(si,ki));
        if abs(ef)>1e-4
            eee=1;
        end
        %Update total residual
        e = [es; ek; ef];
        
        %Update residual norm
        e_norm = norm(e);
        
        %Update iteration counter
        c = c + 1;
    end
    
    %Compute tangent operator
    Jac_inv = inv(Jac); %Inverse of Jacobian matrix
    
    Dti = Jac_inv(1,1)*De; %Consistent tangent operator
    
    %Set yielding flag equalk to 1
    y=1;
    
    %Check value of the residual, if greater than tolerance set error flag
    %to 1
    if (e_norm>tol)
        err=0;
    else
        err=1;
    end
end

end