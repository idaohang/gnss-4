% ����˫����ǰ������45s�����ߣ��������Ƿ���ȷ��������Ԥ������
% ��������ȷ�ᵼ����ķ���ʱ�䲻��ȷ��Ӱ�춨λ

%% ��ʱ��ʼ
clear
clc
tic
% 4������10s���ݺ�ʱԼ16s

%% �ļ�·��
file_path = 'F:\����4_30\data_20190430_164934_ch1.dat';
plot_gnss_file(file_path);
sample_offset = 0*4e6;

%% ȫ�ֱ���
msToProcess = 45*1000; %������ʱ��
sampleFreq = 4e6; %���ջ�����Ƶ��

% �ο�λ��********************
p0 = [45.730952, 126.624970, 212]; %2A¥��

buffBlkNum = 40;                     %�������ݻ����������Ҫ��֤����ʱ�洢ǡ�ô�ͷ��ʼ��
buffBlkSize = 4000;                  %һ����Ĳ���������1ms��
buffSize = buffBlkSize * buffBlkNum; %�������ݻ����С
buff = zeros(1,buffSize);            %�������ݻ���
buffBlkPoint = 0;                    %���ݸ����ڼ���棬��0��ʼ
buffHead = 0;                        %�������ݵ���ţ�buffBlkSize�ı���

%% 1.��ȡ�ļ�ʱ��
tf = sscanf(file_path((end-22):(end-8)), '%4d%02d%02d_%02d%02d%02d')'; %�����ļ���ʼ����ʱ�䣨����ʱ�����飩
[tw, ts] = gps_time(tf); %tw��GPS������ts��GPS��������
ta = [ts,0,0] + sample2dt(sample_offset, sampleFreq); %��ʼ�����ջ�ʱ�䣬[s,ms,us]
ta = time_carry(round(ta,2)); %ȡ��

%% 2.���������ȡ��ǰ���ܼ��������ǣ�*��
% svList = [2;6;12];
svList = gps_constellation(tf, p0);
svN = length(svList);

%% 3.Ϊÿ�ſ��ܼ��������Ƿ������ͨ��
channels = repmat(GPS_L1_CA_channel_struct(), svN,1);
for k=1:svN
    channels(k).PRN = svList(k);
    channels(k).state = 0; %״̬δ����
end

%% Ԥ������
ephemeris_file = ['./ephemeris/',file_path((end-22):(end-8)),'.mat'];
if exist(ephemeris_file, 'file')
    load(ephemeris_file);
    for k=1:svN
        channels(k).ephemeris = ephemeris(k).ephemeris;
    end
end

%% 4.�������ٽ���洢�ռ�
trackResults = repmat(trackResult_struct(msToProcess+100), svN,1);
for k=1:svN
    trackResults(k).PRN = svList(k);
end

%% 5.������������洢�ռ�
m = msToProcess/10;
% ���ջ�ʱ��
receiverTime = zeros(m,3); %[s,ms,us]
% ��λ���
posResult = ones(m,8) * NaN; %λ�á��ٶȡ��Ӳ��Ƶ��
%������λ�á�α�ࡢ�ٶȡ�α���ʲ������
measureResults = cell(svN,1);
for k=1:svN
    measureResults{k} = ones(m,8) * NaN;
end

%% 6.���ļ�������������
fclose('all'); %�ر�֮ǰ�򿪵������ļ�
fileID = fopen(file_path, 'r');
fseek(fileID, round(sample_offset*4), 'bof'); %��ȡ�����ܳ����ļ�ָ���Ʋ���ȥ
if int32(ftell(fileID))~=int32(sample_offset*4)
    error('Sample offset error!');
end
f = waitbar(0, ['0s/',num2str(msToProcess/1000),'s']);

%% 7.�źŴ���
for t=1:msToProcess
    % ���½�����
    if mod(t,1000)==0 %1s����
        waitbar(t/msToProcess, f, [num2str(t/1000),'s/',num2str(msToProcess/1000),'s']);
    end
    
    % �����ݣ�ÿ10s������1.2s��
    rawData = double(fread(fileID, [2,buffBlkSize], 'int16')); %ȡ���ݣ�������
    buff(buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = rawData(1,:) + rawData(2,:)*1i; %ת���ɸ��ź�,���������
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
            if channels(k).state==0 %���ͨ��δ��������Լ���
                [acqResult, peakRatio] = GPS_L1_CA_acq_one(svList(k), buff((end-2*8000+1):end));
                if ~isempty(acqResult) %�ɹ�����
                    channels(k) = GPS_L1_CA_channel_init(channels(k), acqResult, t*buffBlkSize, sampleFreq); %����ͨ��
                    trackResults(k).log = [trackResults(k).log; ...
                                             string(['Acquired at ',num2str(t/1000),'s, peakRatio=',num2str(peakRatio)])];
                end
            end
        end
    end
    
    %% ����
    for k=1:svN %��k��ͨ��
        if channels(k).state~=0 %���ͨ��������и���
            while 1
                % �ж��Ƿ��������ĸ�������
                if mod(buffHead-channels(k).trackDataHead,buffSize)>(buffSize/2)
                    break
                end
                % ����ٽ����ͨ��������
                n = trackResults(k).n;
                trackResults(k).dataIndex(n,:)    = channels(k).dataIndex;
                trackResults(k).ts0(n,:)          = channels(k).ts0;
                trackResults(k).remCodePhase(n,:) = channels(k).remCodePhase;
                trackResults(k).codeFreq(n,:)     = channels(k).codeFreq;
                trackResults(k).remCarrPhase(n,:) = channels(k).remCarrPhase;
                trackResults(k).carrFreq(n,:)     = channels(k).carrFreq;
                % ��������
                trackDataHead = channels(k).trackDataHead;
                trackDataTail = channels(k).trackDataTail;
                if trackDataHead>trackDataTail
                    [channels(k), I_Q, disc, bitStartFlag, others, log] = ...
                        GPS_L1_CA_track(channels(k), sampleFreq, buffSize, buff(trackDataTail:trackDataHead));
                else
                    [channels(k), I_Q, disc, bitStartFlag, others, log] = ...
                        GPS_L1_CA_track(channels(k), sampleFreq, buffSize, [buff(trackDataTail:end),buff(1:trackDataHead)]);
                end
                % ����ٽ�������ٽ����
                trackResults(k).I_Q(n,:)          = I_Q;
                trackResults(k).disc(n,:)         = disc;
                trackResults(k).bitStartFlag(n,:) = bitStartFlag;
                trackResults(k).CN0(n,:)          = channels(k).CN0;
                trackResults(k).others(n,:)       = others;
                trackResults(k).log               = [trackResults(k).log; log];
                trackResults(k).n                 = n + 1;
            end
        end
    end
    
    %% ��λ��ÿ10msһ�Σ�
    if mod(t,10)==0
        n = t/10; %�к�
        receiverTime(n,:) = ta; %����ջ�ʱ��
        sv = zeros(svN,8);
        for k=1:svN %�����ͨ��α��
            if channels(k).state==2 %�Ѿ�����������
                dn = mod(buffHead-channels(k).trackDataTail+1, buffSize) - 1; %trackDataTailǡ�ó�ǰbuffHeadһ��ʱ��dn=-1
                codePhase = channels(k).remCodePhase + (dn/sampleFreq)*channels(k).codeFreq; %��ǰ����λ
                ts0 = channels(k).ts0; %�뿪ʼ��ʱ�䣬ms
                ts0_code = [floor(ts0/1e3), mod(ts0,1e3), 0]; %�뿪ʼ��ʱ�䣬[s,ms,us]��ʱ����[s,ms,us]��ʾ������˹���ʱ�ľ�����ʧ
                ts0_phase = [0, floor(codePhase/1023), mod(codePhase/1023,1)*1e3]; %����λʱ�䣬[s,ms,us]
                [sv(k,:),~] = sv_ecef(channels(k).ephemeris, ta, ts0_code+ts0_phase); %����������������λ�á��ٶȡ�α��
                sv(k,8) = -channels(k).carrFreq/1575.42e6*299792458; %�ز�Ƶ��ת��Ϊ�ٶ�
                measureResults{k}(n,:) = sv(k,:); %�洢
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
    
end

%% 8.�ر��ļ����رս�����
fclose(fileID);
close(f);

%% ɾ�����ٽ���еĿհ�����
for k=1:svN
    trackResults(k) = trackResult_clean(trackResults(k));
end

%% ��ӡͨ����־��*��
clc
for k=1:svN
    if ~isempty(trackResults(k).log)
        disp(['PRN ',num2str(trackResults(k).PRN)])
        n = size(trackResults(k).log,1);
        for kn=1:n
            disp(trackResults(k).log(kn))
        end
        disp(' ')
    end
end
clearvars k n kn

%% ��������
ephemeris = struct('PRN',cell(svN,1), 'ephemeris',cell(svN,1));
for k=1:svN
    ephemeris(k).PRN = channels(k).PRN;
    ephemeris(k).ephemeris = channels(k).ephemeris;
end
save(['./ephemeris/',file_path((end-22):(end-8)),'.mat'], 'ephemeris');

%% ��ͼ��*��
for k=1:svN
    if trackResults(k).n==1 %����û���ٵ�ͨ��
        continue
    end
    
    screenSize = get(0,'ScreenSize'); %��ȡ��Ļ�ߴ�
    
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
%     grid(ax3,'on');
    %----��ͼ
    if screenSize(3)==1920 %������Ļ�ߴ����û�ͼ��Χ
        figure('Position', [390, 280, 1140, 670]);
    elseif screenSize(3)==1368
        figure('Position', [114, 100, 1140, 670]);
    else
        error('Screen size error!')
    end
    ax1 = axes('Position', [0.08, 0.4, 0.38, 0.53]);
    hold(ax1,'on');
    axis(ax1, 'equal');
    title(['PRN = ',num2str(svList(k))])
    ax2 = axes('Position', [0.53, 0.7 , 0.42, 0.25]);
    hold(ax2,'on');
    ax3 = axes('Position', [0.53, 0.38, 0.42, 0.25]);
    hold(ax3,'on');
    grid(ax3,'on');
    ax4 = axes('Position', [0.53, 0.06, 0.42, 0.25]);
    hold(ax4,'on');
    grid(ax4,'on');
    ax5 = axes('Position', [0.05, 0.06, 0.42, 0.25]);
    hold(ax5,'on');
    grid(ax5,'on');
    
    % ��ͼ
    plot(ax1, trackResults(k).I_Q(1001:end,1),trackResults(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.') %I/Qͼ
    plot(ax2, trackResults(k).dataIndex/sampleFreq, trackResults(k).I_Q(:,1)) %I_Pͼ
    index = find(trackResults(k).CN0~=0);
    plot(ax3, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).CN0(index), 'LineWidth',2) %�����
    
%     index = find(trackResults(k).bitStartFlag==double('H')); %Ѱ��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     index = find(trackResults(k).bitStartFlag==double('C')); %У��֡ͷ�׶Σ���ɫ��
%     plot(ax2, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     index = find(trackResults(k).bitStartFlag==double('E')); %���������׶Σ���ɫ��
%     plot(ax2, trackResults(k).dataIndex(index)/sampleFreq, trackResults(k).I_Q(index,1), 'LineStyle','none', 'Marker','.', 'Color','r')

    plot(ax4, trackResults(k).dataIndex/sampleFreq, trackResults(k).carrFreq, 'LineWidth',1.5) %�ز�Ƶ��
    plot(ax5, trackResults(k).dataIndex/sampleFreq, trackResults(k).others(:,1)) %���߷�����ٶ�
    
    % ����������
    set(ax2, 'XLim',[0,msToProcess/1000])
    
    set(ax3, 'XLim',[0,msToProcess/1000])
    set(ax3, 'YLim',[30,60])
    
    set(ax4, 'XLim',[0,msToProcess/1000])
    set(ax5, 'XLim',[0,msToProcess/1000])
end

clearvars k screenSize ax1 ax2 ax3 ax4 ax5 index

%% ���������*��
clearvars -except sampleFreq msToProcess ...
                  p0 tf svList svN ...
                  channels trackResults ...
                  receiverTime measureResults posResult

%% ��ʱ����
toc