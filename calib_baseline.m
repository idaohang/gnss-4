lamda = 299792458 / 1575.42e6;

baseline = 1; %���»��߳���

% ����λ��
lat = pos(1);
lon = pos(2);
h = pos(3);

p0 = lla2ecef([lat, lon, h]);
Cen = dcmecef2ned(lat, lon);

n = 2000; %������ٸ��㣬10msһ����
offset = 0; %ƫ�ƶ��ٸ���
X = ones(n,3) * NaN; %��������һ�к���ǣ��ڶ��и����ǣ������л��߳���

for k=1:n %��k����
    ko = k + offset; %�к�
    p = phaseDiffResult(ko,:)'; %��λ��
    visibleSV = find(isnan(p)==0); %�ҵ�����λ���ͨ����ͨ�����
    svN = length(visibleSV);
    if svN>=4 && ~isnan(posResult(ko,1))%�����Ŀ�����
        p = p(~isnan(p)); %ɾ��NaN
        A = zeros(svN,3);
        for m=1:svN %A�ĵ�m��
            s = measureResults_A{visibleSV(m)}(ko,1:3); %��������
            e = (p0-s) / norm(p0-s); %����ָ�����ߵķ���ʸ��
            A(m,:) = (Cen*e')'; %ת������ϵ��
        end
        [Rx, att, Nx, pe] = IAR_nonbaseline(A, p, lamda, baseline+[-0.1,0.1]);
%         [Rx, att, Nx, pe] = IAR_baseline(A, p, lamda, baseline);
        X(k,:) = att;
    end
end