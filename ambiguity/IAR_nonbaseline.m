function [Rx, att, Nx, pe] = IAR_nonbaseline(A, p, lamda, rho)
% δ֪���߳���������ʸ��������ģ����
% Integer Ambiguity Resolution
% Rx = [x; y; z]
% att = [psi, theta, rho]����ʸ����̬
% Nx = [N1; N2; ...; Nn]����һ��ʼ��Ϊ0
% peΪ��������ģ�������������ģ����Ҫʹ����С
% A�ĸ���Ϊ����ָ�����ߵĵ�λʸ��
% pΪ��������λ������ܲ��֣���λ����
% lamdaΪ��������λ��m
% rhoΪ���߳��ȷ�Χ��[rho_min,rho_max]����λ��m

% ���һ������ų�������·�����ȳ���Ӱ�죨˫���
A = A - ones(size(A,1),1)*A(1,:);
A(1,:) = [];
p = p - p(1);
p(1) = [];

% ȷ������ģ����������Χ
N_max = 2*ceil(rho/lamda); %�����Ͻ磬��2����Ϊ��һ��������
N_min = -N_max; %�����½�

% ��ά��������������Ч�ʣ�
min_pe = inf; %�洢��ǰ��С���������
r11 = A(1,1);
r12 = A(1,2);
r13 = A(1,3);
r21 = A(2,1);
r22 = A(2,2);
r23 = A(2,3);
r31 = A(3,1);
r32 = A(3,2);
r33 = A(3,3);
f = r23*r12 - r13*r22;
d2 = (r23*r11 - r13*r21) /  f;
e2 = (r22*r11 - r12*r21) / -f;
a = 1 + d2^2 + e2^2; %a>0
for N1=N_min:N_max
    for N2=N_min:N_max
        % �жϷ����Ƿ��н�
        % r11*x + r12*y + r13*z = s1 = (phi1 + N1)*lamda
        % r21*x + r22*y + r23*z = s2 = (phi2 + N2)*lamda
        % rho(1)^2 <= x^2 + y^2 + z^2 <= rho(2)^2
        s1 = (p(1)+N1)*lamda;
        s2 = (p(2)+N2)*lamda;
        d1 = (r23*s1 - r13*s2 ) /  f;
        e1 = (r22*s1 - r12*s2 ) / -f;
        b = -2 * (d1*d2 + e1*e2);
        c1 = d1^2 + e1^2 - rho(1)^2;
        c2 = d1^2 + e1^2 - rho(2)^2; %rho(2)>rho(1)��c2<c1
        h1 = b^2-4*a*c1;
        h2 = b^2-4*a*c2; %hΪ�����ݼ�������c2<c1��h2>h1��ֻҪh2<0��h1��ȻС����
        if h2<0 %�����޽�
            continue
        end
        
        %�ж��Ƿ���������N3
        if h1<=0 %N3Ϊ������
            x = (-b-sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e1 = (r31*x + r32*y + r33*z)/lamda - p(3); %N3��һ���߽�
            x = (-b+sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e2 = (r31*x + r32*y + r33*z)/lamda - p(3); %N3����һ���߽�
            % Ѱ��N3�����߽��е�����ֵ
            N3_n = integer_between_edge(N3_e1, N3_e2);
        else %N3Ϊ˫����
            x = (-b-sqrt(h1))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e1 = (r31*x + r32*y + r33*z)/lamda - p(3); %N3��һ�����һ���߽�
            x = (-b-sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e2 = (r31*x + r32*y + r33*z)/lamda - p(3); %N3��һ�������һ���߽�
            % Ѱ��N3�����߽��е�����ֵ
            N3_n1 = integer_between_edge(N3_e1, N3_e2);
            %=============================================================%
            x = (-b+sqrt(h1))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e1 = (r31*x + r32*y + r33*z)/lamda - p(3); %N3�ڶ������һ���߽�
            x = (-b+sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e2 = (r31*x + r32*y + r33*z)/lamda - p(3); %N3�ڶ��������һ���߽�
            % Ѱ��N3�����߽��е�����ֵ
            N3_n2 = integer_between_edge(N3_e1, N3_e2);
            %=============================================================%
            N3_n = [N3_n1, N3_n2];
        end
        
        for N3=N3_n
            % 1.�������ʸ��
            R = A(1:3,:) \ ((p(1:3)+[N1;N2;N3])*lamda);
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

% ȫά����
% min_pe = inf; %�洢��ǰ��С���������
% for N1=N_min:N_max
%     for N2=N_min:N_max
%         for N3=N_min:N_max
%             % 1.�������ʸ��
%             R = A(1:3,:) \ ((p(1:3)+[N1;N2;N3])*lamda);
%             % 2.У����߳���
%             r = norm(R);
%             if r<rho(1) || r>rho(2)
%                 continue
%             end
%             % 3.������������ģ����
%             N = round(A*R/lamda-p);
%             % 4.��С���˼������ʸ��
%             R = (A'*A) \ (A'*(p+N)*lamda);
%             % 5.�Ƚ��������
%             pe = norm(A*R/lamda-N-p);
%             if pe<min_pe
%                 min_pe = pe;
%                 Rx = R;
%                 Nx = N;
%             end
%         end
%     end
% end

att = [0,0,0];
att(3) = norm(Rx); %���߳���
att(1) = atan2d(Rx(2),Rx(1)); %���ߺ����
att(2) = -asind(Rx(3)/att(3)); %���߸�����
Nx = [0; Nx];
pe = min_pe;

end

function n = integer_between_edge(e1, e2)
    if e1>e2
        eu = e1; %�Ͻ�
        ed = e2; %�½�
    else
        eu = e2; %�Ͻ�
        ed = e1; %�½�
    end
    n = ceil(ed):floor(eu); %�½�����ȡ�����Ͻ�����ȡ��
end