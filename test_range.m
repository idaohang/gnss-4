function test_range()

measureResults = evalin('base', 'measureResults');

% �ο�����
p0 = lla2ecef([45.74088083, 126.62694533, 197]);
% p0 = lla2ecef([45.741734, 126.62152, 212]);

T = size(measureResults{1},1); %����
N = length(measureResults); %ͨ����

d_range = ones(T,N) * NaN; %������
d_vel   = ones(T,N) * NaN; %�������
for t=1:T
    for k=1:N
        if ~isnan(measureResults{k}(t,1)) %���ڲ������
            r = measureResults{k}(t,1:3)-p0; %���λ��ʸ�������ջ�ָ������
            R = norm(r); %��ʵ�ľ���
            u = r / R; %��λʸ��
            dR = dot(measureResults{k}(t,5:7), u); %��ʵ������ٶȣ����ջ���ֹ

            rho = measureResults{k}(t,4); %�����ľ���
            d_range(t,k) = rho - R;

            drho = measureResults{k}(t,8); %�������ٶ�
            d_vel(t,k) = drho - dR;
        end
    end
end

assignin('base', 'd_range', d_range);
assignin('base', 'd_vel',   d_vel);

figure
plot((1:T)/100, d_range)
legend_text = cell(1,N);
for k=1:N
    legend_text{k} = ['ch', num2str(k)];
end
legend(legend_text)

figure
plot((1:T)/100, d_vel)
legend_text = cell(1,N);
for k=1:N
    legend_text{k} = ['ch', num2str(k)];
end
legend(legend_text)

end