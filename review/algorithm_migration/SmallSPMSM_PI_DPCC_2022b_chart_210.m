function [y, y1] = carrier(u,Ts)
%#codegen

persistent  count clock
if isempty(count)
    count=0;
    clock = 0;
end

n=round(u/Ts);   % 累加步数
y1=0;
y=count/n*2;
clock = clock + 1;
if clock <= n/2
    count = count + 1;
else 
    count = count - 1;
    
end

if clock  <=1
    y1 = 1;
elseif clock <= (n/2+1) && clock> (n/2-1)
    y1 = 0;  % 此处设为1 即为顶点和低点都有触发信号；
else
    y1 = 0;
end

if clock>=n
    clock=0;  
end
