function [channel, I_Q, disc, bitStartFlag] = GPS_L1_CA_track(channel, sampleFreq, buffSize, rawSignal)

%% �ز���
persistent carrTable
if isempty(carrTable)
    carrTable = exp(-(0:3599)/3600*2*pi*1i);
end

%% ���
bitStartFlag = 0;

%% ����ͨ��ִ�д���
channel.n = channel.n + 1;

%% ��ȡͨ����Ϣ�������㷨�õ��Ŀ��Ʋ�����
trackStage     = channel.trackStage;
msgStage       = channel.msgStage;
cnt            = channel.cnt;
code           = channel.code;
timeInt        = channel.timeInt;
timeIntMs      = channel.timeIntMs;
codeInt        = channel.codeInt;
blkSize        = channel.blkSize;
ts0            = channel.ts0;
carrNco        = channel.carrNco;
codeNco        = channel.codeNco;
carrAcc        = channel.carrAcc;
remCarrPhase   = channel.remCarrPhase;
remCodePhase   = channel.remCodePhase;
I_P0           = channel.I_P0;
Q_P0           = channel.Q_P0;
FLL            = channel.FLL;
PLL            = channel.PLL;
DLL            = channel.DLL;
bitSyncTable   = channel.bitSyncTable;
bitBuff        = channel.bitBuff;
frameBuff      = channel.frameBuff;
frameBuffPoint = channel.frameBuffPoint;
P              = channel.Px; 

%% ��������
% ʱ������
t = (0:blkSize) / sampleFreq;
t_2 = t.^2;

% ���ɱ����ز�
% theta = remCarrPhase + carrNco*t;
theta = remCarrPhase + carrNco*t + 0.5*carrAcc*t_2; %��Ƶ���ز�
% carr = exp(-2*pi*theta(1:end-1)*1i); %�����ز������Ǻ�����
carr = carrTable(mod(round(theta(1:end-1)*3600),3600)+1); %�����ز������
remCarrPhase = mod(theta(end), 1); %ʣ���ز���λ����

% ���ɱ�����
tcode = remCodePhase + codeNco*t;
earlyCode  = code(floor(tcode(1:end-1)+0.5)+2); %��ǰ��
promptCode = code(floor(tcode(1:end-1)    )+2); %��ʱ��
lateCode   = code(floor(tcode(1:end-1)-0.5)+2); %�ͺ���
remCodePhase = tcode(end) - codeInt; %ʣ���ز���λ����

% ԭʼ���ݳ��ز�
BasebandSignal = rawSignal .* carr;
iBasebandSignal = real(BasebandSignal);
qBasebandSignal = imag(BasebandSignal);

% ��·����
I_E = sum(earlyCode  .* iBasebandSignal);
Q_E = sum(earlyCode  .* qBasebandSignal);
I_P = sum(promptCode .* iBasebandSignal);
Q_P = sum(promptCode .* qBasebandSignal);
I_L = sum(lateCode   .* iBasebandSignal);
Q_L = sum(lateCode   .* qBasebandSignal);

% �������
S_E = sqrt(I_E^2+Q_E^2);
S_L = sqrt(I_L^2+Q_L^2);
codeError = 0.5 * (S_E-S_L)/(S_E+S_L); %��λ����Ƭ
% codeError_coherent = 0.5 * (I_E-I_L)/(I_E+I_L);
[channel.codeStd, codeSigma] = std_rec(channel.codeStd ,codeError); %���������������׼��

% �ز�������
carrError = atan(Q_P/I_P) / (2*pi); %��λ����
[channel.carrStd, carrSigma] = std_rec(channel.carrStd ,carrError); %�����ز�����������׼��

% ��Ƶ��
if ~isnan(I_P0)
    yc = I_P0*I_P + Q_P0*Q_P;
    ys = I_P0*Q_P - Q_P0*I_P;
    freqError = atan(ys/yc)/timeInt / (2*pi); %��λ��Hz
else
    freqError = 0;
end

%% �����㷨
switch trackStage
    case 'freqPull' %Ƶ��ǣ��
        %----FLL
        FLL.Int = FLL.Int + FLL.K*freqError*timeInt; %��Ƶ��������
        carrNco = FLL.Int;
        carrFreq = FLL.Int;
        % 500ms��ת����ͳ����
        cnt = cnt + 1;
        if cnt==500
            cnt = 0; %����������
            PLL.Int = FLL.Int; %��ʼ�����໷������
            trackStage = 'tradTrack';
        end
        %----DLL
        DLL.Int = DLL.Int + DLL.K2*codeError*timeInt; %�ӳ�������������
        codeNco = DLL.Int + DLL.K1*codeError;
        codeFreq = DLL.Int;
	case 'tradTrack' %��ͳ����
        %----PLL
        PLL.Int = PLL.Int + PLL.K2*carrError*timeInt; %���໷������
        carrNco = PLL.Int + PLL.K1*carrError;
        carrFreq = PLL.Int;
        % 500ms����б���ͬ��
        if strcmp(msgStage,'idle')
            cnt = cnt + 1;
            if cnt==500
                cnt = 0; %����������
                msgStage = 'bitSync';
            end
        end
        %----DLL
        DLL.Int = DLL.Int + DLL.K2*codeError*timeInt; %�ӳ�������������
        codeNco = DLL.Int + DLL.K1*codeError;
        codeFreq = DLL.Int;
    case 'KalmanTrack' %�������˲�����
        Phi = eye(4);
        Phi(1,3) = timeInt/1540;
        Phi(1,4) = 0.5*timeInt^2/1540;
        Phi(2,3) = timeInt;
        Phi(2,4) = 0.5*timeInt^2;
        Phi(3,4) = timeInt;
        H = zeros(2,4);
        H(1,1) = 1;
        H(2,2) = 1;
        H(2,3) = -timeInt/2;
        Q = diag([0, 0, 3, 0.02].^2) * timeInt^2;
        R = diag([codeSigma, carrSigma].^2);
        Z = [codeError; carrError];
        % �������˲�
        P = Phi*P*Phi' + Q;
        K = P*H' / (H*P*H'+R);
        X = K*Z;
        P = (eye(4)-K*H)*P;
        P = (P+P')/2;
        % ����
        remCodePhase = remCodePhase + X(1);
        remCarrPhase = remCarrPhase + X(2);
        carrNco = carrNco + carrAcc*(blkSize/sampleFreq) + X(3);
        codeNco = 1.023e6 + carrNco/1540;
        carrAcc = carrAcc + X(4);
        carrFreq = carrNco;
        codeFreq = codeNco;
	otherwise
end

%% ���Ľ����㷨
switch msgStage
    case 'bitSync' %����ͬ����������1ms����ʱ�䣬����2s����100�����أ�����ͬ�������ʵ�ָ����Ļ���ʱ��
        cnt = cnt + 1;
        if (I_P0*I_P)<0 %���ֵ�ƽ��ת
            index = mod(cnt-1,20) + 1;
            bitSyncTable(index) = bitSyncTable(index) + 1; %ͳ�Ʊ��еĶ�Ӧλ��1
        end
        if cnt==2000 %2s�����ͳ�Ʊ�
            if max(bitSyncTable)>15 && (sum(bitSyncTable)-max(bitSyncTable))<3 %ȷ����ƽ��תλ��
                [~,cnt] = max(bitSyncTable);
                cnt = -cnt + 1;
                msgStage = 'findHead';
%                 trackStage = 'KalmanTrack';
            else
                cnt = 0; %����������
                msgStage = 'idle';
            end
            bitSyncTable = zeros(1,20); %����ͬ��ͳ�Ʊ�����
        end
        
    case 'findHead' %Ѱ��֡ͷ
        cnt = cnt + 1; 
        if cnt>0 %�����ػ����д���
            bitBuff(cnt) = I_P;
        end
        if cnt==1 %��ǵ�ǰ���ٵ����ݶ�Ϊ���ؿ�ʼλ��
            bitStartFlag = 1;
        end
        if cnt==(20/timeIntMs) %������һ������
            cnt = 0; %����������
            bit = sum(bitBuff(1:(20/timeIntMs))) > 0; %�жϱ���ֵ��0/1
            frameBuffPoint = frameBuffPoint + 1;
            frameBuff(frameBuffPoint) = (bit - 0.5) * 2; %�洢����ֵ����1
            %-------------------------------------------------------------%
            if frameBuffPoint>1502 %����30s��û���ҵ�֡ͷ
                frameBuffPoint = 0;
                frameBuff = zeros(1,1502); %���֡����
                msgStage = 'idle'; %��Ϣ
            elseif frameBuffPoint>=10 %������10�����أ�ǰ��������У��
                if abs(sum(frameBuff(frameBuffPoint+(-7:0)).*[1,-1,-1,-1,1,-1,1,1]))==8 %��⵽����֡ͷ
                    frameBuff(1:10) = frameBuff(frameBuffPoint+(-9:0)); %��֡ͷ��ǰ
                    frameBuffPoint = 10;
                    msgStage = 'checkHead'; %����У��֡ͷģʽ
                end
            end
            %=============================================================%
        end
        
    case 'checkHead' %У��֡ͷ
        cnt = cnt + 1;
        bitBuff(cnt) = I_P; %�����ػ����д���
        if cnt==1 %��ǵ�ǰ���ٵ����ݶ�Ϊ���ؿ�ʼλ��
            bitStartFlag = 2;
        end
        if cnt==(20/timeIntMs) %������һ������
            cnt = 0; %����������
            bit = sum(bitBuff(1:(20/timeIntMs))) > 0; %�жϱ���ֵ��0/1
            frameBuffPoint = frameBuffPoint + 1;
            frameBuff(frameBuffPoint) = (bit - 0.5) * 2; %�洢����ֵ����1
            %-------------------------------------------------------------%
            if frameBuffPoint==62 %�洢��������
                if GPS_L1_CA_check(frameBuff(1:32))==1 && GPS_L1_CA_check(frameBuff(31:62))==1 %У��ͨ��
                    % ��ȡ����ʱ��
                    % bits(32)Ϊ��һ�ֵ����һλ��У��ʱ���Ƶ�ƽ��ת��Ϊ1��ʾ��ת��Ϊ0��ʾ����ת���μ�ICD-GPS���ҳ
                    TOW = -frameBuff(32) * frameBuff(33:49); %31~47����
                    TOW = bin2dec( dec2bin(TOW>0)' );
                    ts0 = (TOW*6-4.8)*1000 - timeIntMs; %ms
                    msgStage = 'parseEphe'; %�����������ģʽ
                else %У��δͨ��
                    for ki=11:62 %���������������û��֡ͷ
                        if abs(sum(frameBuff(ki+(-7:0)).*[1,-1,-1,-1,1,-1,1,1]))==8 %��⵽����֡ͷ
                            frameBuff(1:10) = frameBuff(ki+(-9:0)); %��֡ͷ��ǰ
                            frameBuffPoint = 10;
                            msgStage = 'checkHead'; %����У��֡ͷģʽ
                        else
                            frameBuff(1:9) = frameBuff(54:62); %��δ���ı�����ǰ
                            frameBuffPoint = 9;
                            msgStage = 'findHead'; %�ٴ�Ѱ��֡ͷ
                        end
                    end
                end
            end
            %=============================================================%
        end
        
    case 'parseEphe' %��������
        cnt = cnt + 1;
        bitBuff(cnt) = I_P; %�����ػ����д���
        if cnt==1 %��ǵ�ǰ���ٵ����ݶ�Ϊ���ؿ�ʼλ��
            bitStartFlag = 3;
        end
        if cnt==(20/timeIntMs) %������һ������
            cnt = 0; %����������
            bit = sum(bitBuff(1:(20/timeIntMs))) > 0; %�жϱ���ֵ��0/1
            frameBuffPoint = frameBuffPoint + 1;
            frameBuff(frameBuffPoint) = (bit - 0.5) * 2; %�洢����ֵ����1
            %-------------------------------------------------------------%
            if frameBuffPoint==1502 %������5֡
                ephemeris = GPS_L1_CA_ephemeris(frameBuff); %��������
                if ephemeris(2)==ephemeris(3) %��������Ƿ�ı�
                    channel.ephemeris = ephemeris; %��������
                    channel.state = 1; %����״̬
                else
                    disp(['PRN ',num2str(channel.PRN),],' ephemeris change.');
                end
                frameBuff(1:2) = frameBuff(1501:1502); %���������������ǰ
                frameBuffPoint = 2;
            end
            %=============================================================%
        end
        
    otherwise
end

%% ����ͨ����Ϣ1
channel.dataIndex = channel.dataIndex + blkSize;
trackDataHead = channel.trackDataHead;
trackDataTail = trackDataHead + 1;
if trackDataTail>buffSize
    trackDataTail = trackDataTail - buffSize;
end
blkSize = ceil((codeInt-remCodePhase)/codeNco*sampleFreq);
trackDataHead = trackDataTail + blkSize - 1;
if trackDataHead>buffSize
    trackDataHead = trackDataHead - buffSize;
end
channel.ts0           = ts0 + timeIntMs;
channel.trackDataTail = trackDataTail;
channel.blkSize       = blkSize;
channel.trackDataHead = trackDataHead;

%% ����ͨ����Ϣ2
channel.trackStage     = trackStage;
channel.msgStage       = msgStage;
channel.cnt            = cnt;
channel.code           = code;
channel.timeInt        = timeInt;
channel.timeIntMs      = timeIntMs;
channel.codeInt        = codeInt;
channel.carrNco        = carrNco;
channel.codeNco        = codeNco;
channel.carrAcc        = carrAcc;
channel.carrFreq       = carrFreq;
channel.codeFreq       = codeFreq;
channel.remCarrPhase   = remCarrPhase;
channel.remCodePhase   = remCodePhase;
channel.I_P0           = I_P;
channel.Q_P0           = Q_P;
channel.FLL            = FLL;
channel.PLL            = PLL;
channel.DLL            = DLL;
channel.bitSyncTable   = bitSyncTable;
channel.bitBuff        = bitBuff;
channel.frameBuff      = frameBuff;
channel.frameBuffPoint = frameBuffPoint;
channel.Px             = P;

%% ���
I_Q = [I_P, I_E, I_L, Q_P, Q_E, Q_L];
% disc = [codeError, carrError, freqError];
% disc = [codeError, codeSigma, carrError, carrSigma, freqError];
disc = [codeError, codeSigma, carrError, carrSigma, freqError, carrAcc];

end