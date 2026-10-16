function v=pmsm_vector_transform(abc,theta)
% Amplitude-invariant Clarke, followed by the model's d-axis Park convention.
validateattributes(abc,{'double'},{'real','finite','2d','ncols',3});
validateattributes(theta,{'double'},{'real','finite','vector'});
theta=theta(:);assert(numel(theta)==size(abc,1),'角度与电流必须逐样本对应。');
alpha=(2*abc(:,1)-abc(:,2)-abc(:,3))/3;
beta=(abc(:,2)-abc(:,3))/sqrt(3);zero=sum(abc,2)/3;
d=alpha.*cos(theta)+beta.*sin(theta);q=-alpha.*sin(theta)+beta.*cos(theta);
v=struct('alpha_beta_A',[alpha beta],'zero_A',zero,'dq_A',[d q], ...
 'abc_reconstructed_A',[alpha+zero,-alpha/2+sqrt(3)*beta/2+zero,-alpha/2-sqrt(3)*beta/2+zero]);
end
