%% ��ʱ��ʼ
clear
clc
tic

%% �ļ�·��
file_path_A = 'E:\GNSS data\outdoor_static\data_20190410_172036_ch1.dat';
file_path_B = 'E:\GNSS data\outdoor_static\data_20190410_172036_ch2.dat';
sample_offset = 0*4e6;

%% ȫ�ֱ���
msToProcess = 20*1000; %������ʱ��
sampleFreq = 4e6; %���ջ�����Ƶ��

p0 = [45.74088083, 126.62694533, 197]; %�ο�λ��********************

buffBlkNum = 40;                     %�������ݻ����������Ҫ��֤����ʱ�洢ǡ�ô�ͷ��ʼ��
buffBlkSize = 4000;                  %һ����Ĳ���������1ms��
buffSize = buffBlkSize * buffBlkNum; %�������ݻ����С
buff = zeros(2,buffSize);            %�������ݻ��棨���зֱ�Ϊ�������ߣ�
buffBlkPoint = 0;                    %���ݸ����ڼ���棬��0��ʼ
buffHead = 0;                        %�������ݵ���ţ�buffBlkSize�ı���

%% 1.��ȡ�ļ�ʱ��
tf = sscanf(file_path_A((end-22):(end-8)), '%4d%02d%02d_%02d%02d%02d')'; %�����ļ���ʼ����ʱ�䣨����ʱ�����飩
[tw, ts] = gps_time(tf); %tw��GPS������ts��GPS��������
ta = [ts,0,0] + sample2dt(sample_offset, sampleFreq); %��ʼ�����ջ�ʱ�䣬[s,ms,us]
ta = time_carry(round(ta,2)); %ȡ��

%% 2.���������ȡ��ǰ���ܼ���������
% svList = [2;6;12];
svList = gps_constellation(tf, p0);
svN = length(svList);

%% 3.Ϊÿ�ſ��ܼ��������Ƿ������ͨ��
channels_A = repmat(GPS_L1_CA_channel_struct(), svN,1);
channels_B = repmat(GPS_L1_CA_channel_struct(), svN,1);
for k=1:svN
    channels_A(k).PRN = svList(k);
    channels_A(k).state = 0; %״̬δ����
    channels_B(k).PRN = svList(k);
    channels_B(k).state = 0; %״̬δ����
end

%% Ԥ������
ephemeris_file = ['./ephemeris/',file_path_A((end-22):(end-8)),'.mat'];
if exist(ephemeris_file, 'file')
    load(ephemeris_file);
    for k=1:svN
        channels_A(k).ephemeris = ephemeris(k).ephemeris;
        channels_B(k).ephemeris = ephemeris(k).ephemeris;
    end
end

%% 4.�������ٽ���洢�ռ�
trackResults_A = repmat(trackResult_struct(msToProcess+100), svN,1);
trackResults_B = repmat(trackResult_struct(msToProcess+100), svN,1);
for k=1:svN
    trackResults_A(k).PRN = svList(k);
    trackResults_B(k).PRN = svList(k);
end

%% 5.������������洢�ռ�
m = msToProcess/10;
% ���ջ�ʱ��
receiverTime = zeros(m,3); %[s,ms,us]
% ��λ���
posResult = ones(m,8) * NaN; %λ�á��ٶȡ��Ӳ��Ƶ��
% ��λ��
phaseDiffResult = ones(m,svN) * NaN;
%������λ�á�α�ࡢ�ٶȡ�α���ʲ������
measureResults_A = cell(svN,1);
measureResults_B = cell(svN,1);
for k=1:svN
    measureResults_A{k} = ones(m,8) * NaN;
    measureResults_B{k} = ones(m,8) * NaN;
end

%% 6.���ļ�������������
fclose('all'); %�ر�֮ǰ�򿪵������ļ�
% �ļ�A
fileID_A = fopen(file_path_A, 'r');
fseek(fileID_A, round(sample_offset*4), 'bof');
if int32(ftell(fileID_A))~=int32(sample_offset*4)
    error('Sample offset error!');
end
% �ļ�B
fileID_B = fopen(file_path_B, 'r');
fseek(fileID_B, round(sample_offset*4), 'bof');
if int32(ftell(fileID_B))~=int32(sample_offset*4)
    error('Sample offset error!');
end
% ������
f = waitbar(0, ['0s/',num2str(msToProcess/1000),'s']);

%% 7.�źŴ���
for t=1:msToProcess
    % ���½�����
    if mod(t,1000)==0 %1s����
        waitbar(t/msToProcess, f, [num2str(t/1000),'s/',num2str(msToProcess/1000),'s']);
    end
    
    % ������
    rawData = double(fread(fileID_A, [2,buffBlkSize], 'int16'));
    buff(1,buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = rawData(1,:) + rawData(2,:)*1i; %����A
    rawData = double(fread(fileID_B, [2,buffBlkSize], 'int16'));
    buff(2,buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = rawData(1,:) + rawData(2,:)*1i; %����B
    buffBlkPoint = buffBlkPoint + 1;
    buffHead = buffBlkPoint * buffBlkSize;
    if buffBlkPoint==buffBlkNum
        buffBlkPoint = 0; %�����ͷ��ʼ
    end
    
    % ���½��ջ�ʱ�䣨��ǰ���һ�������Ľ��ջ�ʱ�䣩
% 	ta = time_carry(ta + sample2dt(buffBlkSize, sampleFreq));
    ta = time_carry(ta + [0,1,0]);
    
    %% ����1s����һ�Σ�
    if mod(t,1000)==0
        for k=1:svN %�������п��ܼ���������
            %====����A
            if channels_A(k).state==0 %���ͨ��δ��������Լ���
                [acqResult, peakRatio] = GPS_L1_CA_acq_one(svList(k), buff(1,(end-2*8000+1):end));
                if ~isempty(acqResult) %�ɹ�����
                    channels_A(k) = GPS_L1_CA_channel_init(channels_A(k), acqResult, t*buffBlkSize, sampleFreq); %����ͨ��
                    trackResults_A(k).log = [trackResults_A(k).log; ...
                                             string(['Acquired at ',num2str(t/1000),'s, peakRatio=',num2str(peakRatio)])];
                end
            end
            %====����B
            if channels_B(k).state==0 %���ͨ��δ��������Լ���
                [acqResult, peakRatio] = GPS_L1_CA_acq_one(svList(k), buff(2,(end-2*8000+1):end));
                if ~isempty(acqResult) %�ɹ�����
                    channels_B(k) = GPS_L1_CA_channel_init(channels_B(k), acqResult, t*buffBlkSize, sampleFreq); %����ͨ��
                    trackResults_B(k).log = [trackResults_B(k).log; ...
                                             string(['Acquired at ',num2str(t/1000),'s, peakRatio=',num2str(peakRatio)])];
                end
            end
        end
    end
    
    %% ����
    for k=1:svN
        %====����A
        if channels_A(k).state~=0 %���ͨ��������и���
            while 1
                % �ж��Ƿ��������ĸ�������
                if mod(buffHead-channels_A(k).trackDataHead,buffSize)>(buffSize/2)
                    break
                end
                % ����ٽ����ͨ��������
                n = trackResults_A(k).n;
                trackResults_A(k).dataIndex(n,:)    = channels_A(k).dataIndex;
                trackResults_A(k).ts0(n,:)          = channels_A(k).ts0;
                trackResults_A(k).remCodePhase(n,:) = channels_A(k).remCodePhase;
                trackResults_A(k).codeFreq(n,:)     = channels_A(k).codeFreq;
                trackResults_A(k).remCarrPhase(n,:) = channels_A(k).remCarrPhase;
                trackResults_A(k).carrFreq(n,:)     = channels_A(k).carrFreq;
                % ��������
                trackDataHead = channels_A(k).trackDataHead;
                trackDataTail = channels_A(k).trackDataTail;
                if trackDataHead>trackDataTail
                    [channels_A(k), I_Q, disc, bitStartFlag, others, log] = ...
                        GPS_L1_CA_track(channels_A(k), sampleFreq, buffSize, buff(1,trackDataTail:trackDataHead));
                else
                    [channels_A(k), I_Q, disc, bitStartFlag, others, log] = ...
                        GPS_L1_CA_track(channels_A(k), sampleFreq, buffSize, [buff(1,trackDataTail:end),buff(1,1:trackDataHead)]);
                end
                % ����ٽ�������ٽ����
                trackResults_A(k).I_Q(n,:)          = I_Q;
                trackResults_A(k).disc(n,:)         = disc;
                trackResults_A(k).bitStartFlag(n,:) = bitStartFlag;
                trackResults_A(k).CN0(n,:)          = channels_A(k).CN0;
                trackResults_A(k).others(n,:)       = others;
                trackResults_A(k).log               = [trackResults_A(k).log; log];
                trackResults_A(k).n                 = n + 1;
            end
        end
        %====����B
        if channels_B(k).state~=0 %���ͨ��������и���
            while 1
                % �ж��Ƿ��������ĸ�������
                if mod(buffHead-channels_B(k).trackDataHead,buffSize)>(buffSize/2)
                    break
                end
                % ����ٽ����ͨ��������
                n = trackResults_B(k).n;
                trackResults_B(k).dataIndex(n,:)    = channels_B(k).dataIndex;
                trackResults_B(k).ts0(n,:)          = channels_B(k).ts0;
                trackResults_B(k).remCodePhase(n,:) = channels_B(k).remCodePhase;
                trackResults_B(k).codeFreq(n,:)     = channels_B(k).codeFreq;
                trackResults_B(k).remCarrPhase(n,:) = channels_B(k).remCarrPhase;
                trackResults_B(k).carrFreq(n,:)     = channels_B(k).carrFreq;
                % ��������
                trackDataHead = channels_B(k).trackDataHead;
                trackDataTail = channels_B(k).trackDataTail;
                if trackDataHead>trackDataTail
                    [channels_B(k), I_Q, disc, bitStartFlag, others, log] = ...
                        GPS_L1_CA_track(channels_B(k), sampleFreq, buffSize, buff(2,trackDataTail:trackDataHead));
                else
                    [channels_B(k), I_Q, disc, bitStartFlag, others, log] = ...
                        GPS_L1_CA_track(channels_B(k), sampleFreq, buffSize, [buff(2,trackDataTail:end),buff(2,1:trackDataHead)]);
                end
                % ����ٽ�������ٽ����
                trackResults_B(k).I_Q(n,:)          = I_Q;
                trackResults_B(k).disc(n,:)         = disc;
                trackResults_B(k).bitStartFlag(n,:) = bitStartFlag;
                trackResults_B(k).CN0(n,:)          = channels_B(k).CN0;
                trackResults_B(k).others(n,:)       = others;
                trackResults_B(k).log               = [trackResults_B(k).log; log];
                trackResults_B(k).n                 = n + 1;
            end
        end
    end
    
    %% ��λ��ÿ10msһ�Σ���ʱʹ��A����
    if mod(t,10)==0
        n = t/10; %�к�
        receiverTime(n,:) = ta; %����ջ�ʱ��
        %--------�����ͨ��α��--------%
        sv = zeros(svN,8);
        for k=1:svN
            if channels_A(k).state==2 %�Ѿ�����������
                dn = mod(buffHead-channels_A(k).trackDataTail+1, buffSize) - 1; %trackDataTailǡ�ó�ǰbuffHeadһ��ʱ��dn=-1
                codePhase = channels_A(k).remCodePhase + (dn/sampleFreq)*channels_A(k).codeFreq; %��ǰ����λ
                ts0 = channels_A(k).ts0; %�뿪ʼ��ʱ�䣬ms
                ts0_code = [floor(ts0/1e3), mod(ts0,1e3), 0]; %�뿪ʼ��ʱ�䣬[s,ms,us]
                ts0_phase = [0, floor(codePhase/1023), mod(codePhase/1023,1)*1e3]; %����λʱ�䣬[s,ms,us]
                [sv(k,:),~] = sv_ecef(channels_A(k).ephemeris, ta, ts0_code+ts0_phase); %����������������λ�á��ٶȡ�α��
                sv(k,8) = -channels_A(k).carrFreq/1575.42e6*299792458; %�ز�Ƶ��ת��Ϊ�ٶ�
                measureResults_A{k}(n,:) = sv(k,:); %�洢
            end
        end
        sv(sv(:,1)==0,:) = []; %ɾ��û���ٵ�����
        %--------��λ--------%
        if size(sv,1)>=4
            pos = pos_solve(sv);
            if abs(pos(7))>0.1 %�Ӳ����0.1msʱУ�����ջ���
                ta = ta - sec2smu(pos(7)/1000);
            else
                posResult(n,:) = pos; %��׼��ʱ��棬ʱ�Ӳ�׼�������λ����ƫ����¶�λ��׼
            end
        end
    end
    
    %% ������������λ�B-A����ÿ10msһ�Σ�
    if mod(t,10)==0
        n = t/10; %�к�
        for k=1:svN
            if channels_A(k).state==2 && channels_B(k).state==2 %�������߶����ٵ��ÿ�����
                % ����A
                dn = mod(buffHead-channels_A(k).trackDataTail+1, buffSize) - 1; %dn���ܵ���-1
                dt = dn / sampleFreq;
                phase_A = channels_A(k).remCarrPhase + channels_A(k).carrFreq*dt + 0.5*channels_A(k).carrAcc*dt^2; %�ز���λ
                % ����B
                dn = mod(buffHead-channels_B(k).trackDataTail+1, buffSize) - 1; %dn���ܵ���-1
                dt = dn / sampleFreq;
                phase_B = channels_B(k).remCarrPhase + channels_B(k).carrFreq*dt + 0.5*channels_B(k).carrAcc*dt^2; %�ز���λ
                % ��λ�С�����֣�
                if channels_A(k).inverseFlag*channels_B(k).inverseFlag==1 %����������λ��ת��ͬ
                    phaseDiffResult(n,k) = mod(phase_B-phase_A, 1); %��λ����
                else %����������λ��ת��ͬ
                    phaseDiffResult(n,k) = mod(phase_B-phase_A+0.5, 1); %��λ����
                end
            end
        end
    end
end

%% 8.�ر��ļ����رս�����
fclose(fileID_A);
fclose(fileID_B);
close(f);

%% ɾ�����ٽ���еĿհ�����
for k=1:svN
    trackResults_A(k) = trackResult_clean(trackResults_A(k));
    trackResults_B(k) = trackResult_clean(trackResults_B(k));
end

%% ��ӡͨ����־
clc
disp('<--------antenna A-------->')
for k=1:svN
    if ~isempty(trackResults_A(k).log)
        disp(['PRN ',num2str(trackResults_A(k).PRN)])
        n = size(trackResults_A(k).log,1);
        for kn=1:n
            disp(trackResults_A(k).log(kn))
        end
        disp(' ')
    end
end
disp('<--------antenna B-------->')
for k=1:svN
    if ~isempty(trackResults_B(k).log)
        disp(['PRN ',num2str(trackResults_B(k).PRN)])
        n = size(trackResults_B(k).log,1);
        for kn=1:n
            disp(trackResults_B(k).log(kn))
        end
        disp(' ')
    end
end

%% ��������
ephemeris = struct('PRN',cell(svN,1), 'ephemeris',cell(svN,1));
for k=1:svN
    ephemeris(k).PRN = channels_A(k).PRN;
    if ~isempty(channels_A(k).ephemeris)
        ephemeris(k).ephemeris = channels_A(k).ephemeris;
    else
        ephemeris(k).ephemeris = channels_B(k).ephemeris;
    end
end
save(['./ephemeris/',file_path_A((end-22):(end-8)),'.mat'], 'ephemeris');

%% ��ͼ
for k=1:svN
    if trackResults_A(k).n==1 && trackResults_B(k).n==1 %����û���ٵ�ͨ��
        continue
    end
    
    % ����������
    %----��ͼ
%     figure('Position', [380, 440, 1160, 480]);
%     ax1 = axes('Position', [0.05, 0.12, 0.4, 0.8]);
%     hold(ax1,'on');
%     axis(ax1, 'equal');
%     title(['PRN = ',num2str(svList(k))])
%     ax2 = axes('Position', [0.5, 0.58, 0.46, 0.34]);
%     hold(ax2,'on');
%     ax3 = axes('Position', [0.5, 0.12, 0.46, 0.34]);
%     hold(ax3,'on');
    %----��ͼ
    figure('Position', [390, 280, 1140, 670]);
    ax1 = axes('Position', [0.08, 0.4, 0.38, 0.53]);
    hold(ax1,'on');
    axis(ax1, 'equal');
    title(['PRN = ',num2str(svList(k))])
    ax2 = axes('Position', [0.53, 0.7 , 0.42, 0.25]);
    hold(ax2,'on');
    ax3 = axes('Position', [0.53, 0.38, 0.42, 0.25]);
    hold(ax3,'on');
    ax4 = axes('Position', [0.53, 0.06, 0.42, 0.25]);
    hold(ax4,'on');
    grid(ax4,'on');
    ax5 = axes('Position', [0.05, 0.06, 0.42, 0.25]);
    hold(ax5,'on');
    grid(ax5,'on');
    
    % ��ͼ
    plot(ax1, trackResults_A(k).I_Q(1001:end,1),trackResults_A(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.', 'Color',[0,0.447,0.741])
    plot(ax2, trackResults_A(k).dataIndex/sampleFreq, trackResults_A(k).I_Q(:,1), 'Color',[0,0.447,0.741])
    
%     index = find(trackResults_A(k).bitStartFlag==double('H')); %Ѱ��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults_A(k).dataIndex(index)/sampleFreq, trackResults_A(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     index = find(trackResults_A(k).bitStartFlag==double('C')); %У��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults_A(k).dataIndex(index)/sampleFreq, trackResults_A(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     index = find(trackResults_A(k).bitStartFlag==double('E')); %���������׶Σ���ɫ��
%     plot(ax2, trackResults_A(k).dataIndex(index)/sampleFreq, trackResults_A(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','r')
    %---------------------------------------------------------------------%
    plot(ax1, trackResults_B(k).I_Q(1001:end,1),trackResults_B(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.', 'Color',[0.850,0.325,0.098])
    plot(ax3, trackResults_B(k).dataIndex/sampleFreq, trackResults_B(k).I_Q(:,1), 'Color',[0.850,0.325,0.098])
    
%     index = find(trackResults_B(k).bitStartFlag==double('H')); %Ѱ��֡ͷ�׶Σ���ɫ��
%     plot(ax3, trackResults_B(k).dataIndex(index)/sampleFreq, trackResults_B(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     index = find(trackResults_B(k).bitStartFlag==double('C')); %У��֡ͷ�׶Σ���ɫ��
%     plot(ax3, trackResults_B(k).dataIndex(index)/sampleFreq, trackResults_B(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     index = find(trackResults_B(k).bitStartFlag==double('E')); %���������׶Σ���ɫ��
%     plot(ax3, trackResults_B(k).dataIndex(index)/sampleFreq, trackResults_B(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','r')

    plot(ax4, trackResults_A(k).dataIndex/sampleFreq, trackResults_A(k).carrFreq, 'LineWidth',1.5, 'Color',[0,0.447,0.741]) %�ز�Ƶ��
    plot(ax4, trackResults_B(k).dataIndex/sampleFreq, trackResults_B(k).carrFreq, 'LineWidth',1.5, 'Color',[0.850,0.325,0.098])
    
    plot(ax5, trackResults_A(k).dataIndex/sampleFreq, trackResults_A(k).others(:,1), 'Color',[0,0.447,0.741]) %���߷�����ٶ�
    plot(ax5, trackResults_B(k).dataIndex/sampleFreq, trackResults_B(k).others(:,1), 'Color',[0.850,0.325,0.098])
    
    % ����������
    set(ax2, 'XLim',[0,msToProcess/1000])
    set(ax3, 'XLim',[0,msToProcess/1000])

    ax2_ylim = get(ax2, 'YLim');
    ax3_ylim = get(ax3, 'YLim');
    ylim = max(abs([ax2_ylim,ax3_ylim]));
    set(ax2, 'YLim',[-ylim,ylim])
    set(ax3, 'YLim',[-ylim,ylim])
    
    set(ax4, 'XLim',[0,msToProcess/1000])
    set(ax5, 'XLim',[0,msToProcess/1000])
end

%% ��ʱ����
toc