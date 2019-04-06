%% ��ʱ��ʼ
tic

%% ������
acqPRN = find(~isnan(acqResults(:,1)))'; %���񵽵����Ǳ���б�
chN = length(acqPRN); %ͨ������

%% ȫ�ֱ���
msToProcess = 60*1000; %������ʱ��
sampleFreq = 4e6; %���ջ�����Ƶ��

buffBlkNum = 40;                     %�������ݻ��������
buffBlkSize = 4000;                  %һ����Ĳ�������
buffSize = buffBlkSize * buffBlkNum; %�������ݻ����С
buff = zeros(1,buffSize);            %�������ݻ���
buffBlkPoint = 0;                    %���ݸ����ڼ���棬��0��ʼ
buffHead = 0;                        %�������ݵ���ţ�buffBlkSize�ı���

%% ʱ��
tf = sscanf(file_path((end-22):(end-8)), '%4d%02d%02d_%02d%02d%02d')';
[~, tf] = gps_time(tf); %�����ļ���ʼ����ʱ�䣨GPSʱ�䣬���ڵ�������
ta = [tf,0,0] + sample2dt(sample_offset, sampleFreq); %��ʼ�����ջ�ʱ��
ta = time_carry(round(ta,2)); %ȡ��

%% ��ʼ��ͨ��
channel = GPS_L1_CA_channel_struct();
channels = repmat(channel, chN,1);
clearvars channel
for k=1:chN
    PRN = acqPRN(k);
    code = GPS_L1_CA_generate(PRN);
    channels(k).PRN = PRN;
    channels(k).n = 1;
    channels(k).state = 0;
    channels(k).trackStage = 'freqPull';
    channels(k).msgStage = 'idle';
    channels(k).cnt = 0;
    channels(k).code = [code(end),code,code(1)];
    channels(k).timeInt = 0.001;
    channels(k).timeIntMs = 1;
    channels(k).codeInt = 1023;
    channels(k).trackDataTail = sampleFreq*0.001 - acqResults(PRN,1) + 2;
    channels(k).blkSize = sampleFreq * 0.001;
    channels(k).trackDataHead = channels(k).trackDataTail + channels(k).blkSize - 1;
    channels(k).dataIndex = channels(k).trackDataTail;
    channels(k).ts0 = NaN;
    channels(k).carrNco = acqResults(PRN,2);
    channels(k).codeNco = 1.023e6 + channels(k).carrNco/1540;
    channels(k).carrAcc = 0;
    channels(k).carrFreq = channels(k).carrNco;
    channels(k).codeFreq = channels(k).codeNco;
    channels(k).remCarrPhase = 0;
    channels(k).remCodePhase = 0;
    channels(k).I_P0 = NaN;
    channels(k).Q_P0 = NaN;
    channels(k).FLL.K = 40;
    channels(k).FLL.Int = channels(k).carrNco;
    [K1, K2] = orderTwoLoopCoef(25, 0.707, 1);
    channels(k).PLL.K1 = K1;
    channels(k).PLL.K2 = K2;
    channels(k).PLL.Int = 0;
    [K1, K2] = orderTwoLoopCoef(2, 0.707, 1);
    channels(k).DLL.K1 = K1;
    channels(k).DLL.K2 = K2;
    channels(k).DLL.Int = channels(k).codeNco;
    channels(k).bitSyncTable = zeros(1,20);
    channels(k).bitBuff = zeros(1,20);
    channels(k).frameBuff = zeros(1,1502);
    channels(k).frameBuffPoint = 0;
    channels(k).ephemeris = zeros(26,1);
    % ���������������׼��ṹ��
    channels(k).codeStd.buff = zeros(1,200);
    channels(k).codeStd.buffSize = length(channels(k).codeStd.buff);
    channels(k).codeStd.buffPoint = 0;
    channels(k).codeStd.E0 = 0;
    channels(k).codeStd.D0 = 0;
    % �����ز�����������׼��ṹ��
    channels(k).carrStd.buff = zeros(1,200);
    channels(k).carrStd.buffSize = length(channels(k).carrStd.buff);
    channels(k).carrStd.buffPoint = 0;
    channels(k).carrStd.E0 = 0;
    channels(k).carrStd.D0 = 0;
    channels(k).Px = diag([0.02, 0.01, 5, 1].^2); %6m, 3.6deg, 5Hz, 1Hz/s
end

%% �������ٽ���洢�ռ�
dn = 100;
trackResult.PRN = 0;
trackResult.dataIndex     = zeros(msToProcess+dn,1); %�����ڿ�ʼ��������ԭʼ�����ļ��е�λ��
trackResult.ts0           = zeros(msToProcess+dn,1); %���������۷���ʱ�䣬ms
trackResult.remCodePhase  = zeros(msToProcess+dn,1); %�����ڿ�ʼ�����������λ����Ƭ
trackResult.codeFreq      = zeros(msToProcess+dn,1); %��Ƶ��
trackResult.remCarrPhase  = zeros(msToProcess+dn,1); %�����ڿ�ʼ��������ز���λ����
trackResult.carrFreq      = zeros(msToProcess+dn,1); %�ز�Ƶ��
trackResult.I_Q           = zeros(msToProcess+dn,6); %[I_P,I_E,I_L,Q_P,Q_E,Q_L]
trackResult.disc          = zeros(msToProcess+dn,6); %[codeError,carrError,freqError]
trackResult.bitStartFlag  = zeros(msToProcess+dn,1);
trackResults = repmat(trackResult, chN,1);
clearvars trackResult
for k=1:chN
    trackResults(k).PRN = acqPRN(k);
end

%% ������������洢�ռ�
measureResults = cell(1,chN+1); %��һ����ʱ�䣬�����Ǹ���ͨ��
measureResults{1} = zeros(msToProcess/10,3); %���ջ�ʱ�䣬[s,ms,us]
for k=1:chN
    measureResults{k+1} = ones(msToProcess/10,8)*NaN;
end
posResult = ones(msToProcess/10,8)*NaN; %�涨λ���

%% ���ļ�������������
fileID = fopen(file_path, 'r');
if fileID~=3 %�ر���ǰ�򿪵��ļ�
    for k=3:(fileID-1)
        fclose(k);
    end
end
fseek(fileID, round(sample_offset*4), 'bof'); %��ȡ�����ܳ����ļ�ָ���Ʋ���ȥ
if int32(ftell(fileID))~=int32(sample_offset*4)
    error('Sample offset error!');
end
f = waitbar(0, ['0s/',num2str(msToProcess/1000),'s']);

%% �źŴ���
for t=1:msToProcess
    % ���½�����
    if mod(t,1000)==0
        waitbar(t/msToProcess, f, [num2str(t/1000),'s/',num2str(msToProcess/1000),'s']);
    end
    
    % 1.�����ݣ�ÿ10s������1.2s��
    rawData = double(fread(fileID, [2,buffBlkSize], 'int16')); %ȡ���ݣ�������
    buff(buffBlkPoint*buffBlkSize+(1:buffBlkSize)) = rawData(1,:) + rawData(2,:)*1i; %ת���ɸ��ź�,���������
    buffBlkPoint = buffBlkPoint + 1;
    buffHead = buffBlkPoint * buffBlkSize;
    if buffBlkPoint==buffBlkNum
        buffBlkPoint = 0; %�����ͷ��ʼ
    end
    
    % 2.���½��ջ�ʱ�䣨��ǰ���һ�������Ľ��ջ�ʱ�䣩
	ta = time_carry(ta + sample2dt(buffBlkSize, sampleFreq));
    
    % 3.ͨ������
    for k=1:chN %��k��ͨ��
        while 1
            % �ж��Ƿ��������ĸ�������
            if mod(buffHead-channels(k).trackDataHead,buffSize)>(buffSize/2)
                break
            end
            
            % ����ٽ����ͨ��������
            n = channels(k).n;
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
                [channels(k), I_Q, disc, bitStartFlag] = ...
                    GPS_L1_CA_track(channels(k), sampleFreq, buffSize, buff(trackDataTail:trackDataHead));
            else
                [channels(k), I_Q, disc, bitStartFlag] = ...
                    GPS_L1_CA_track(channels(k), sampleFreq, buffSize, [buff(trackDataTail:end),buff(1:trackDataHead)]);
            end
            
            % ����ٽ�������ٽ����
            trackResults(k).I_Q(n,:)          = I_Q; 
            trackResults(k).disc(n,:)         = disc;
            trackResults(k).bitStartFlag(n,:) = bitStartFlag;
        end
    end
    
    % 4.���������ÿ40000�����������һ�Σ�
    % �����Ӳ�׼����Ӱ���࣬����Ե�����ת����任����Ӱ�죬Ҫʵʱ�����Ӳ����Ƶ��
    if mod(t,10)==0
        sv = zeros(chN,8);
        n = t/10;
        measureResults{1}(n,:) = ta; %����ջ�ʱ��
        for k=1:chN
            if channels(k).state==1 %�Ѿ�����������
                dn = mod(buffHead-channels(k).trackDataTail+buffSize/2, buffSize) - buffSize/2;
                codePhase = channels(k).remCodePhase + (dn/sampleFreq)*channels(k).codeFreq; %��ǰ����λ
                %----------------------------------------------------------------------------------------------------------%
%                 ts0 = channels(k).ts0/1e3 + codePhase/1.023e6;
%                 tr = ta(1) + ta(2)/1e3 + ta(3)/1e6;
%                 [sv(k,:),~] = sv_ecef_0(channels(k).ephemeris, tr, ts0); %����������������λ�á��ٶȡ�α��
                %----------------------------------------------------------------------------------------------------------%
                % ʱ����[s,ms,us]��ʾ������˹���ʱ�ľ�����ʧ
                ts0 = channels(k).ts0; %�뿪ʼ��ʱ�䣬ms
                ts0_code = [floor(ts0/1e3), mod(ts0,1e3), 0]; %�뿪ʼ��ʱ�䣬[s,ms,us]
                ts0_phase = [0, floor(codePhase/1023), mod(codePhase/1023,1)*1e3]; %����λʱ�䣬[s,ms,us]
                [sv(k,:),~] = sv_ecef(channels(k).ephemeris, ta, ts0_code+ts0_phase); %����������������λ�á��ٶȡ�α��
                %----------------------------------------------------------------------------------------------------------%
                sv(k,8) = -channels(k).carrFreq/1575.42e6*299792458; %�ز�Ƶ��ת��Ϊ�ٶ�
                measureResults{k+1}(n,:) = sv(k,:); %�洢
            end
        end
        sv(sv(:,1)==0,:) = [];
        if size(sv,1)>=4 %��λ
            posResult(n,:) = pos_solve(sv);
        end
    end
end

%% �ر��ļ����رս�����
fclose(fileID);
close(f);

%% ɾ�����ٽ���еĿհ�����
for k=1:size(trackResults,1)
    n = channels(k).n;
    trackResults(k).dataIndex(n:end,:)    = [];
    trackResults(k).ts0(n:end,:)          = [];
    trackResults(k).remCodePhase(n:end,:) = [];
    trackResults(k).codeFreq(n:end,:)     = [];
    trackResults(k).remCarrPhase(n:end,:) = [];
    trackResults(k).carrFreq(n:end,:)     = [];
    trackResults(k).I_Q(n:end,:)          = [];
    trackResults(k).disc(n:end,:)         = [];
    trackResults(k).bitStartFlag(n:end,:) = [];
end

%% ��I/Qͼ
for k=1:size(trackResults,1)
    figure
    plot(trackResults(k).I_Q(1001:end,1),trackResults(k).I_Q(1001:end,4), 'LineStyle','none', 'Marker','.') %��1s֮���ͼ
    axis equal
    title(['PRN = ',num2str(trackResults(k).PRN)])
end
clearvars k

%% ��Ǳ��ؿ�ʼλ��
% for k=1:size(trackResults,1)
%     figure
%     plot(trackResults(k).I_Q(:,1))
%     hold on
%     indexBitStart = find(trackResults(k).bitStartFlag==1); %Ѱ��֡ͷ�׶�
%     plot(indexBitStart, trackResults(k).I_Q(indexBitStart,1), 'LineStyle','none', 'Marker','.', 'Color','m')
%     indexBitStart = find(trackResults(k).bitStartFlag==2); %У��֡ͷ�׶�
%     plot(indexBitStart, trackResults(k).I_Q(indexBitStart,1), 'LineStyle','none', 'Marker','.', 'Color','b')
%     indexBitStart = find(trackResults(k).bitStartFlag==3); %���������׶�
%     plot(indexBitStart, trackResults(k).I_Q(indexBitStart,1), 'LineStyle','none', 'Marker','.', 'Color','r')
%     title(['PRN = ',num2str(trackResults(k).PRN)])
% end
% clearvars k indexBitStart

%% �������
clearvars -except acqResults file_path sample_offset channels trackResults ta measureResults posResult

%% ��ʱ����
toc