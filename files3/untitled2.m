rng(42);
n = 1000000;
e = ones(n,1);
A = spdiags([-e 2*e -e], -1:1, n, n);
b1 = rand(n,1);
b2 = rand(n,1);
b=[b1,b2];
% Method 1: two backslash calls (old approach)
tic
x1_bs = A \ b1;
x2_bs = A \ b2;
toc
% Method 2: single LU, two triangular solves (P4.2)
tic
[L, U] = lu(A);
% solve_f = @(b) Q * (U \ (L \ (P * b)));
x1_lu  = U \ (L \  b1);
x2_lu  = U \ (L \ b2);
toc

tic
x=A\b;
x1=x(:,1);
x2=x(:,2);
toc