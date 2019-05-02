% ���Զ̻�������ģ���������㷨
% �۲�R��Rx�Ƿ���ȡ�att�����õ���̬�Ƿ���ȡ�N��Nx��ͬһ������

%% ��������
lamda = 299792458 / 1575.42e6;

% ���ǵķ�λ�ǡ��߶Ƚ�
sv = [0,   45;
      23,  28;
      58,  80;
      100, 49;
      146, 34;
      186, 78;
      213, 43;
      255, 86;
      310, 20];

% ����ʸ��
psi = 270;
theta = 22;
rho = 1.9;
R = [cosd(theta)*cosd(psi); cosd(theta)*sind(psi); -sind(theta)] * rho;

n = size(sv,1);
A = zeros(n,3);
p = zeros(n,1);
N = zeros(n,1);
for k=1:n
    A(k,:) = [-cosd(sv(k,2))*cosd(sv(k,1)); -cosd(sv(k,2))*sind(sv(k,1)); sind(sv(k,2))]; %����ָ������
    phase = dot(A(k,:),R) / lamda + randn(1)*0.005; %��λ�����������λ����
    N(k) = floor(phase); %��������
    p(k) = mod(phase,1); %С������
end

%% �������ģ����
% [att, Rx, Nx, pe] = IAR_baseline(A, p, lamda, rho); %��֪�����������ģ����
[att, Rx, Nx, i1, pe] = IAR_nonbaseline(A, p, lamda, rho+[-0.1,0.1]); %δ֪�����������ģ����

if length(unique(N-Nx))~=1 %N-NxӦ�ö���ͬ�������ͬ˵�������
    error('Error!')
end