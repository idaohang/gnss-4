function calib_baseline()

%% �������
p0 = evalin('base', 'p0');
svList = evalin('base', 'svList');
svN = evalin('base', 'svN');
phaseDiffResult = evalin('base', 'phaseDiffResult');
measureResults = evalin('base', 'measureResults_A');

%%
n0 = 2001; %���㿪ʼ��
n1 = 4000; %���������
n = n1 - n0 + 1; %�������

lamda = 299792458 / 1575.42e6; %����

bl = 0.4; %���»��߳���
br = 0.1; %���߳��ȷ�Χ

Cen = dcmecef2ned(p0(1), p0(2));
p0 = lla2ecef(p0); %����λ�ã�ecef

%% �������ʸ��
BLs = ones(n,3) * NaN; %����߲����������һ�к���ǣ��ڶ��и����ǣ������л��߳���
pd0 = ones(n,svN) * NaN; %������λ��
pdn = ones(n,svN) * NaN; %ʵ����λ�������

for k=n0:n1
    p = phaseDiffResult(k,:)'; %��λ�������
    A = zeros(svN,3);
    for m=1:svN
        s = measureResults{m}(k,1:3); %��������
        e = (p0-s) / norm(p0-s); %����ָ�����ߵĵ�λʸ��
        A(m,:) = (Cen*e')'; %ת������ϵ��
    end
    index = find(isnan(p)==0); %����λ���ͨ����
    if length(index)>=5
        [att, Rx] = IAR_nonbaseline(A(index,:), p(index), lamda, bl+[-br,br]);
        BLs(k-n0+1,:) = att;
        pdx = A*Rx / lamda;
        pd0(k-n0+1,:) = pdx';
        pdn(k-n0+1,:) = (round(pdx-p)+p)';
    end
end

%% ��ͼ
figure
subplot(3,1,1)
plot(BLs(:,1))
grid on
title('�����')
set(gca,'Ylim',[-180,180])

subplot(3,1,2)
plot(BLs(:,2))
grid on
title('������')
set(gca,'Ylim',[-90,90])

subplot(3,1,3)
plot(BLs(:,3))
grid on
title('���߳���')
set(gca,'Ylim',[bl-br,bl+br])

colorTable = [    0, 0.447, 0.741;
              0.850, 0.325, 0.098;
              0.929, 0.694, 0.125;
              0.494, 0.184, 0.556;
              0.466, 0.674, 0.188;
              0.301, 0.745, 0.933;
              0.635, 0.078, 0.184;
                  0,     0,     1;
                  1,     0,     0;
                  0,     1,     0;
                  0,     0,     0;];
figure
hold on
grid on
legend_str = [];
for k=1:svN
    if sum(~isnan(pd0(:,k)))~=0
        plot(pd0(:,k), 'LineWidth',0.5, 'Color',colorTable(k,:))
        eval('legend_str = [legend_str; string(num2str(svList(k)))];')
    end
end
for k=1:svN
    if sum(~isnan(pdn(:,k)))~=0
        plot(pdn(:,k), 'LineWidth',2, 'Color',colorTable(k,:))
        eval('legend_str = [legend_str; string(num2str(svList(k)))];')
    end
end
legend(legend_str)

%% ���
disp(mean(BLs,1,'omitnan'))
disp(std(BLs,0,1,'omitnan')*3)

phaseDiffResult0 = mod(pd0,1);
assignin('base', 'phaseDiffResult0', phaseDiffResult0);

end