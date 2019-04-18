function [Rx, att, Nx, pe] = IAR_baseline(A, p, lamda, rho)
% ��֪���߳���������ʸ��������ģ����
% Integer Ambiguity Resolution
% Rx = [x; y; z]
% att = [psi, theta, rho]����ʸ����̬
% Nx = [N1; N2; ...; Nn]����һ��ʼ��Ϊ0
% peΪ��������ģ�������������ģ����Ҫʹ����С
% A�ĸ���Ϊ����ָ�����ߵĵ�λʸ��
% pΪ��������λ������ܲ��֣���λ����
% lamdaΪ��������λ��m
% rhoΪ���߳��ȣ���λ��m

% ���һ������ų�������·�����ȳ���Ӱ�죨˫���
A = A - ones(size(A,1),1)*A(1,:);
A(1,:) = [];
p = p - p(1);
p(1) = [];

% ȷ������ģ����������Χ
N_max = 2*ceil(rho/lamda); %�����Ͻ磬��2��Ϊ��һ��������
N_min = -N_max; %�����½�

% ����
min_pe = inf; %�洢��ǰ��С���������
r11 = A(1,1);
r12 = A(1,2);
r13 = A(1,3);
r21 = A(2,1);
r22 = A(2,2);
r23 = A(2,3);
f = r23*r12 - r13*r22;
d2 = (r23*r11 - r13*r21) /  f;
e2 = (r22*r11 - r12*r21) / -f;
a = 1 + d2^2 + e2^2;
for N1=N_min:N_max
    for N2=N_min:N_max
        % �жϷ����Ƿ��н�
        % r11*x + r12*y + r13*z = s1 = (phi1 + N1)*lamda
        % r21*x + r22*y + r23*z = s2 = (phi2 + N2)*lamda
        % x^2 + y^2 + z^2 = rho^2
        s1 = (p(1)+N1)*lamda;
        s2 = (p(2)+N2)*lamda;
        d1 = (r23*s1 - r13*s2 ) /  f;
        e1 = (r22*s1 - r12*s2 ) / -f;
        b = -2 * (d1*d2 + e1*e2);
        c = d1^2 + e1^2 - rho^2;
        h = b^2-4*a*c;
        if h<0 %�����޽�
            continue
        end
        
        for x=[(-b+sqrt(h))/(2*a), (-b-sqrt(h))/(2*a)]
            % 1.�������ʸ��
            y = d1 - d2*x;
            z = e1 - e2*x;
            R = [x;y;z];
            % 2.������������ģ����
            N = round(A*R/lamda-p);
            % 3.��С���˼������ʸ��
            R = (A'*A) \ (A'*(p+N)*lamda);
            % 4.�Ƚ��������
            pe = norm(A*R/lamda-N-p);
            if pe<min_pe
                min_pe = pe;
                Rx = R;
                Nx = N;
            end
        end
    end
end

att = [0,0,0];
att(3) = norm(Rx); %���߳���
att(1) = atan2d(Rx(2),Rx(1)); %���ߺ����
att(2) = -asind(Rx(3)/att(3)); %���߸�����
Nx = [0; Nx];
pe = min_pe;

end