function [att, Rx, Nx, i1, pe] = IAR_nonbaseline(A, p, lamda, rho)
% δ֪���߳���������ʸ��������ģ����
% Integer Ambiguity Resolution
% att = [psi, theta, rho]����ʸ����̬
% Rx = [x; y; z]
% Nx = [N1; N2; ...; Nn]
% i1˫��ı�����
% peΪ��������ģ�������������ģ����Ҫʹ����С
% A�ĸ���Ϊ����ָ�����ߵĵ�λʸ��
% pΪ��������λ������ܲ��֣���λ����
% lamdaΪ��������λ��m
% rhoΪ���߳��ȷ�Χ��[rho_min,rho_max]����λ��m

% ��߶Ƚ���ߵ�����ų�������·�����ȳ���Ӱ�죨˫���
ele = asind(A(:,3)); %�������Ǹ߶Ƚ�
[~,i1] = max(ele); %�߶Ƚ���ߵ���
A = A - ones(size(A,1),1)*A(i1,:);
A(i1,:) = [];
p = p - p(i1);
p(i1) = [];

% Ѱ���������
D_max = 0;
n = size(A,1);
for I2=1:(n-2)
    for I3=(I2+1):(n-1)
        for I4=(I3+1):n
            C = [A(I2,:); A(I3,:); A(I4,:)];
            [~,D] = eig(C'*C);
            D = diag(D);
            D = min(D); %����ֵ����Сֵ
            if D>D_max %Ѱ�����ֵ
                D_max = D;
                i2 = I2;
                i3 = I3;
                i4 = I4;
            end
        end
    end
end

% ȷ������ģ����������Χ
N_max = 2*ceil(rho(2)/lamda); %�����Ͻ磬��2����Ϊ��һ��������
N_min = -N_max; %�����½�

% ��ά��������������Ч�ʣ�
pe_min = 100; %�洢��ǰ��С���������
r11 = A(i2,1);
r12 = A(i2,2);
r13 = A(i2,3);
r21 = A(i3,1);
r22 = A(i3,2);
r23 = A(i3,3);
r31 = A(i4,1);
r32 = A(i4,2);
r33 = A(i4,3);
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
        s1 = (p(i2)+N1)*lamda;
        s2 = (p(i3)+N2)*lamda;
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
            N3_e1 = (r31*x + r32*y + r33*z)/lamda - p(i4); %N3��һ���߽�
            x = (-b+sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e2 = (r31*x + r32*y + r33*z)/lamda - p(i4); %N3����һ���߽�
            % Ѱ��N3�����߽��е�����ֵ
            N3_n = integer_between_edge(N3_e1, N3_e2);
        else %N3Ϊ˫����
            x = (-b-sqrt(h1))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e1 = (r31*x + r32*y + r33*z)/lamda - p(i4); %N3��һ�����һ���߽�
            x = (-b-sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e2 = (r31*x + r32*y + r33*z)/lamda - p(i4); %N3��һ�������һ���߽�
            % Ѱ��N3�����߽��е�����ֵ
            N3_n1 = integer_between_edge(N3_e1, N3_e2);
            %=============================================================%
            x = (-b+sqrt(h1))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e1 = (r31*x + r32*y + r33*z)/lamda - p(i4); %N3�ڶ������һ���߽�
            x = (-b+sqrt(h2))/(2*a);
            y = d1 - d2*x;
            z = e1 - e2*x;
            N3_e2 = (r31*x + r32*y + r33*z)/lamda - p(i4); %N3�ڶ��������һ���߽�
            % Ѱ��N3�����߽��е�����ֵ
            N3_n2 = integer_between_edge(N3_e1, N3_e2);
            %=============================================================%
            N3_n = [N3_n1, N3_n2];
        end
        
        for N3=N3_n
            % 1.�������ʸ��
            R = A([i2,i3,i4],:) \ ((p([i2,i3,i4])+[N1;N2;N3])*lamda);
            % 2.������������ģ����
            N = round(A*R/lamda-p);
            % 3.��С���˼������ʸ��
            R = (A'*A) \ (A'*(p+N)*lamda);
            % 4.�Ƚ��������
            pe = norm(A*R/lamda-N-p);
            if pe<pe_min
                pe_min = pe;
                Rx = R;
                Nx = N;
            end
        end
    end
end

if exist('Rx', 'var')
    att = [0,0,0];
    att(3) = norm(Rx); %���߳���
    att(1) = atan2d(Rx(2),Rx(1)); %���ߺ����
    att(2) = -asind(Rx(3)/att(3)); %���߸�����
    Nx = [Nx(1:i1-1); 0; Nx(i1:end)];
    pe = pe_min;
else
    att = [NaN, NaN, NaN]; %������
    Rx = [NaN; NaN; NaN]; %������
    Nx = ones(length(p),1) * NaN; %������
    i1 = NaN;
    pe = NaN;
end

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