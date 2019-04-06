function test_range()

measureResults = evalin('base', 'measureResults');

p0 = lla2ecef([45.74088083, 126.62694533, 197]);

T = size(measureResults{1},1);
N = size(measureResults,2) - 1;

d_range = zeros(T, N);
d_vel = zeros(T, N);
for t=1:T
    for k=1:N
        r = measureResults{k+1}(t,1:3)-p0; %���λ��ʸ�������ջ�ָ������
        R = norm(r); %��ʵ�ľ���
        u = r / R;
        dR = dot(measureResults{k+1}(t,5:7), u); %��ʵ������ٶȣ����ջ���ֹ
        
        rho = measureResults{k+1}(t,4); %�����ľ���
        d_range(t,k) = rho - R;
        
        drho = measureResults{k+1}(t,8); %�������ٶ�
        d_vel(t,k) = drho - dR;
    end
end

assignin('base', 'd_range', d_range);
assignin('base', 'd_vel', d_vel);

figure
plot((1:T)/100, d_range)
legend_text = cell(1,N);
for k=1:N
    legend_text{k} = ['ch', num2str(k)];
end
legend(legend_text)
% set(gca, 'xlim', [0,T/100])

figure
plot((1:T)/100, d_vel)
legend_text = cell(1,N);
for k=1:N
    legend_text{k} = ['ch', num2str(k)];
end
legend(legend_text)
legend(legend_text)
% set(gca, 'xlim', [0,T/100])

end