function [ coords, connectivity ] = orthogonal_truss( n1, n2, l1, l2 )

coords = zeros((n1+1)*(n2+1),2);
connectivity = zeros(n1*(1+n2*3),2);

c=1;

dl1 = l1/n1;
dl2 = l2/n2;

for j=1:(n2+1)
    for i=1:(n1+1)
        coords(c,:)=[(i-1)*dl1 (j-1)*dl2];
        c =c+1;
    end
end

c=1;

for j=1:n2
    for i=1:n1
        connectivity(c,:) =   [i+(j-1)*(n1+1)          i+1+(j-1)*(n1+1)];
        connectivity(c+1,:) = [i+1+(j-1)*(n1+1)        i+1+j*(n1+1)];
        connectivity(c+2,:) = [i+(j-1)*(n1+1)          i+1+j*(n1+1)];
        c=c+3;
    end
end

for i=1:n1
    connectivity(c,:)=[n2*(n1+1)+i n2*(n1+1)+i+1];
    c=c+1;
end

end