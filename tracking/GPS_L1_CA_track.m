function [channel, I_Q, disc, bitStartFlag, others, log] = GPS_L1_CA_track(channel, sampleFreq, buffSize, rawSignal)

%% �ز���
persistent carrTable
if isempty(carrTable)
    carrTable = exp(-(0:3599)/3600*2*pi*1i);
end

%% ���
bitStartFlag = 0;
log = [];

%% ��ȡͨ����Ϣ�������㷨�õ��Ŀ��Ʋ�����
trackStage     = channel.trackStage;
msgStage       = channel.msgStage;
cnt_t          = channel.cnt_t;
cnt_m          = channel.cnt_m;
code           = channel.code;
timeIntMs      = channel.timeIntMs;
codeInt        = channel.codeInt;
pointInt       = channel.pointInt;
blkSize        = channel.blkSize;
dataIndex      = channel.dataIndex + blkSize;
ts0            = channel.ts0;
carrNco        = channel.carrNco;
codeNco        = channel.codeNco;
carrAcc        = channel.carrAcc;
remCarrPhase   = channel.remCarrPhase;
remCodePhase   = channel.remCodePhase;
carrCirc       = channel.carrCirc;
I_P0           = channel.I_P0;
Q_P0           = channel.Q_P0;
FLL            = channel.FLL;
PLL            = channel.PLL;
DLL            = channel.DLL;
bitSyncTable   = channel.bitSyncTable;
bitBuff        = channel.bitBuff;
frameBuff      = channel.frameBuff;
frameBuffPoint = channel.frameBuffPoint;
CN0            = channel.CN0;
P              = channel.Px;

timeInt = timeIntMs * 0.001; %����ʱ�䣬s

%% ��������
% ʱ������
t = (0:blkSize) / sampleFreq;
t_2 = t.^2;

% ���ɱ����ز�
% theta = remCarrPhase + carrNco*t; %��Ƶ���ز�
theta = remCarrPhase + carrNco*t + 0.5*carrAcc*t_2; %��Ƶ���ز�
% carr = exp(-2*pi*theta(1:end-1)*1i); %�����ز������Ǻ�����
carr = carrTable(mod(round(theta(1:end-1)*3600),3600)+1); %�����ز������
remCarrPhase = mod(theta(end), 1); %ʣ���ز���λ����
carrCirc = mod(carrCirc+floor(theta(end)), 1000); %�ز�������������

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
% codeError_coherent = 0.5 * (I_E-I_L)/(I_E+I_L); %��ɼ�����
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
    case 'F' %<<====Ƶ��ǣ��
        %----FLL
        FLL.Int = FLL.Int + FLL.K*freqError*timeInt; %��Ƶ��������
        carrNco = FLL.Int;
        carrFreq = FLL.Int;
        % 500ms��ת����ͳ����
        cnt_t = cnt_t + 1;
        if cnt_t==500
            cnt_t = 0; %����������
            PLL.Int = FLL.Int; %��ʼ�����໷������
            trackStage = 'T';
            log = [log; ...
                   string(['Start traditional tracking at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
        end
        %----DLL
        DLL.Int = DLL.Int + DLL.K2*codeError*timeInt; %�ӳ�������������
        codeNco = DLL.Int + DLL.K1*codeError;
        codeFreq = DLL.Int;
        
	case 'T' %<<====��ͳ����
        %----PLL
        PLL.Int = PLL.Int + PLL.K2*carrError*timeInt; %���໷������
        carrNco = PLL.Int + PLL.K1*carrError;
        carrFreq = PLL.Int;
        % 500ms����б���ͬ��
        if msgStage=='I'
            cnt_t = cnt_t + 1;
            if cnt_t==500
                cnt_t = 0; %����������
                msgStage = 'B';
                log = [log; ...
                       string(['Start bit synchronization at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
            end
        end
        %----DLL
        DLL.Int = DLL.Int + DLL.K2*codeError*timeInt; %�ӳ�������������
        codeNco = DLL.Int + DLL.K1*codeError;
        codeFreq = DLL.Int;
        
    case 'K' %<<====�������˲�����
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
        % Q�������������Ҫ���ڣ���һ����Ӧ��Ƶ���������ڶ�����Ӧ��Ư�Ƶ�����
%         Q = diag([0, 0, 3, 0.02].^2) * timeInt^2;
%         Q = diag([0, 0, 1, 0.01].^2) * timeInt^2;
        Q = diag([0, 0, 4, 2].^2) * timeInt^2;
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
switch msgStage %I, B, W, H, C, E
    case 'I' %<<====����
        
    case 'B' %<<====����ͬ��
        % ������1ms����ʱ�䣬����2s����100������
        % ����ͬ�������ʵ�ָ����Ļ���ʱ��
        % ����ͬ������Խ�������ȼ���
        cnt_m = cnt_m + 1;
        if (I_P0*I_P)<0 %���ֵ�ƽ��ת
            index = mod(cnt_m-1,20) + 1;
            bitSyncTable(index) = bitSyncTable(index) + 1; %ͳ�Ʊ��еĶ�Ӧλ��1
        end
        if cnt_m==2000 %2s�����ͳ�Ʊ�
            if max(bitSyncTable)>15 && (sum(bitSyncTable)-max(bitSyncTable))<=5 %ȷ����ƽ��תλ�ã���ƽ��ת�󶼷�����һ�����ϣ�
                %------------------------------------------------------------------------------------%
                trackStage = 'K'; %����ͬ����ת���������˲�����
                log = [log; ...
                       string(['Start Kalman tracking at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
                %------------------------------------------------------------------------------------%
                [~,cnt_m] = max(bitSyncTable);
                bitSyncTable = zeros(1,20); %����ͬ��ͳ�Ʊ�����
                cnt_m = -cnt_m + 1;
                if cnt_m==0
                    msgStage = 'H'; %����Ѱ��֡ͷģʽ
                    log = [log; ...
                           string(['Start find head at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
                else
                    msgStage = 'W'; %����ȴ�cnt_m==0ģʽ
                end
            else
                channel.state = 0; %����ͬ��ʧ�ܣ��ر�ͨ��
                log = [log; ...
                       string(['**Bit synchronization fails at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
            end
        end
        
    case 'W' %<<====�ȴ�cnt_m==0
        cnt_m = cnt_m + 1;
        if cnt_m==0
            msgStage = 'H'; %����Ѱ��֡ͷģʽ
            log = [log; ...
                   string(['Start find head at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
        end
        
    otherwise %<<====�Ѿ���ɱ���ͬ��
        cnt_m = cnt_m + 1;
        bitBuff(1,cnt_m) = I_P; %�����ػ����д���
        bitBuff(2,cnt_m) = Q_P; %�����ػ����д���
        if cnt_m==1 %��ǵ�ǰ���ٵ����ݶ�Ϊ���ؿ�ʼλ��
            bitStartFlag = double(msgStage);
        end
        if cnt_m==pointInt %������һ������
            cnt_m = 0; %����������
            %-------------------------------------------------------------%
            % ���������
            Ps = bitBuff(1,1:pointInt).^2 + bitBuff(2,1:pointInt).^2; %ÿ����Ĺ���
            WBP = sum(Ps); %������ʣ����е�Ĺ�����ͣ���ƽ������ͣ�
            Is = sum(bitBuff(1,1:pointInt)); %�ϳ�I
            Qs = sum(bitBuff(2,1:pointInt)); %�ϳ�Q
            NBP = Is^2 + Qs^2; %խ�����ʣ��ϳ�IQ�Ĺ��ʣ��ź�Խ�ã�խ������Խ���������ƽ����
            if CN0==0 %��ʼ�����ֵ�ṹ��
                channel.NWmean.buff = ones(1,channel.NWmean.buffSize)*(NBP/WBP);
                channel.NWmean.E0 = NBP/WBP;
            end
            [channel.NWmean, NWm] = mean_rec(channel.NWmean ,NBP/WBP); %����Z�ľ�ֵ
            CN0 = 10*log10((NWm-1)/(pointInt-NWm)/timeInt); %�����
            if CN0<=35 %�ж�Ϊʧ��
                channel.state = 0;
                log = [log; ...
                       string(['**Lose lock at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
            end
            %-------------------------------------------------------------%
            bit = sum(bitBuff(1,1:pointInt)) > 0; %�жϱ���ֵ��0/1
            frameBuffPoint = frameBuffPoint + 1;
            frameBuff(frameBuffPoint) = (double(bit) - 0.5) * 2; %�洢����ֵ����1
            switch msgStage
                case 'H' %<<====Ѱ��֡ͷ
                    if frameBuffPoint>=10 %������10�����أ�ǰ��������У��
                        if abs(sum(frameBuff(frameBuffPoint+(-7:0)).*[1,-1,-1,-1,1,-1,1,1]))==8 %��⵽����֡ͷ
                            frameBuff(1:10) = frameBuff(frameBuffPoint+(-9:0)); %��֡ͷ��ǰ
                            frameBuffPoint = 10;
                            msgStage = 'C'; %����У��֡ͷģʽ
                        end
                    end
                    if frameBuffPoint==1502 %��ֹBug��һ�㵽�������30s��û�ҵ�֡ͷ��ͱ��ж�Ϊʧ����
                        frameBuffPoint = 0;
                    end
                case 'C' %<<====У��֡ͷ
                    if frameBuffPoint==310 %�洢��һ����֡��2+300+8
                        if GPS_L1_CA_check(frameBuff(1:32))==1 && GPS_L1_CA_check(frameBuff(31:62))==1  && ... %У��ͨ��
                            abs(sum(frameBuff(303:310).*[1,-1,-1,-1,1,-1,1,1]))==8
                            % ��ȡ����ʱ��
                            % frameBuff(32)Ϊ��һ�ֵ����һλ��У��ʱ���Ƶ�ƽ��ת��Ϊ1��ʾ��ת��Ϊ0��ʾ����ת���μ�ICD-GPS���ҳ
                            bits = -frameBuff(32) * frameBuff(33:49); %��ƽ��ת��31~47����
                            bits = dec2bin(bits>0)'; %��1����ת��Ϊ01�ַ���
                            TOW = bin2dec(bits); %01�ַ���ת��Ϊʮ������
                            ts0 = (TOW*6+0.16)*1000 - timeIntMs; %ms��0.16=8/50
                            channel.inverseFlag = frameBuff(62); %��λ��ת��־��1��ʾ��ת��-1��ʾ����ת
                            if ~isempty(channel.ephemeris)
                                channel.state = 2; %����״̬��֪���뷢��ʱ�䣬������������
                            end
                            msgStage = 'E'; %�����������ģʽ
                            log = [log; ...
                                   string(['Start parse ephemeris at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
                        else %У��δͨ��
                            for k=11:310 %���������������û��֡ͷ
                                if abs(sum(frameBuff(k+(-7:0)).*[1,-1,-1,-1,1,-1,1,1]))==8 %��⵽����֡ͷ
                                    frameBuff(1:320-k) = frameBuff(k-9:310); %��֡ͷ�ͺ���ı�����ǰ��320-k = 310-(k-9)+1
                                    frameBuffPoint = 320-k;
                                    break
                                end
                            end
                            if frameBuffPoint==310 %û��⵽����֡ͷ
                                frameBuff(1:9) = frameBuff(302:310); %��δ���ı�����ǰ
                                frameBuffPoint = 9;
                                msgStage = 'H'; %�ٴ�Ѱ��֡ͷ
                            end
                        end
                    end
%                     if frameBuffPoint==62 %�洢��������
%                         if GPS_L1_CA_check(frameBuff(1:32))==1 && GPS_L1_CA_check(frameBuff(31:62))==1  && ... %У��ͨ��
%                             frameBuff(61)==frameBuff(62) %�п��ܳ��ָ��ֵĿ�ͷǡ��Ϊ֡ͷ�����ӣ���һ���жϣ����������������
%                             % ��ȡ����ʱ��
%                             % frameBuff(32)Ϊ��һ�ֵ����һλ��У��ʱ���Ƶ�ƽ��ת��Ϊ1��ʾ��ת��Ϊ0��ʾ����ת���μ�ICD-GPS���ҳ
%                             bits = -frameBuff(32) * frameBuff(33:49); %��ƽ��ת��31~47����
%                             bits = dec2bin(bits>0)'; %��1����ת��Ϊ01�ַ���
%                             TOW = bin2dec(bits); %01�ַ���ת��Ϊʮ������
%                             ts0 = (TOW*6-4.8)*1000 - timeIntMs; %ms
%                             channel.inverseFlag = frameBuff(62); %��λ��ת��־��1��ʾ��ת��-1��ʾ����ת
%                             if ~isempty(channel.ephemeris)
%                                 channel.state = 2; %����״̬��֪���뷢��ʱ�䣬������������
%                             end
%                             msgStage = 'E'; %�����������ģʽ
%                             log = [log; ...
%                                    string(['Start parse ephemeris at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
%                         else %У��δͨ��
%                             for k=11:62 %���������������û��֡ͷ
%                                 if abs(sum(frameBuff(k+(-7:0)).*[1,-1,-1,-1,1,-1,1,1]))==8 %��⵽����֡ͷ
%                                     frameBuff(1:72-k) = frameBuff(k-9:62); %��֡ͷ�ͺ���ı�����ǰ��72-k = 62-(k-9)+1
%                                     frameBuffPoint = 72-k;
%                                     break
%                                 end
%                             end
%                             if frameBuffPoint==62 %û��⵽����֡ͷ
%                                 frameBuff(1:9) = frameBuff(54:62); %��δ���ı�����ǰ
%                                 frameBuffPoint = 9;
%                                 msgStage = 'H'; %�ٴ�Ѱ��֡ͷ
%                             end
%                         end
%                     end
                case 'E' %<<====��������
                    if frameBuffPoint==1502 %������5֡
                        ephemeris = GPS_L1_CA_ephemeris(frameBuff); %��������
                        if isempty(ephemeris) %��������
                            log = [log; ...
                                   string(['**Ephemeris error at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
                            bits = -frameBuff(62) * frameBuff; %��ƽ��ת
                            bits = dec2bin(bits>0)'; %��1����ת��Ϊ01�ַ���
                            log = [log; string(bits(1:2))];
                            for k=1:50 %������ĵ�����������ҵ��Ĵ���ԭ��
                                eval('log = [log; string(bits((k-1)*30+2+(1:30)))];')
                            end
                            frameBuffPoint = 0;
                            msgStage = 'H'; %����Ѱ��֡ͷ
                            log = [log; ...
                                   string(['Start find head at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
                        else
                            if ephemeris(2)~=ephemeris(3) %�����ı�
                                log = [log; ...
                                       string(['**Ephemeris changes at ',num2str(dataIndex/sampleFreq,'%.8f'),'s, IODC=',num2str(ephemeris(2)),', IODE=',num2str(ephemeris(3))])];
                            else
                                channel.ephemeris = ephemeris; %��������
                                channel.state = 2; %����״̬��֪���뷢��ʱ�䣬������������
                                log = [log; ...
                                       string(['Ephemeris is parsed at ',num2str(dataIndex/sampleFreq,'%.8f'),'s'])];
                            end
                            frameBuff(1:2) = frameBuff(1501:1502); %���������������ǰ
                            frameBuffPoint = 2;
                        end
                    end
                otherwise
            end
        end
        
end

%% ����ͨ����Ϣ1
trackDataHead = channel.trackDataHead;
trackDataTail = trackDataHead + 1;
if trackDataTail>buffSize
    trackDataTail = 1;
end
blkSize = ceil((codeInt-remCodePhase)/codeNco*sampleFreq);
trackDataHead = trackDataTail + blkSize - 1;
if trackDataHead>buffSize
    trackDataHead = trackDataHead - buffSize;
end
channel.trackDataTail = trackDataTail;
channel.blkSize       = blkSize;
channel.trackDataHead = trackDataHead;
channel.dataIndex     = dataIndex;
channel.ts0           = ts0 + timeIntMs;

%% ����ͨ����Ϣ2
channel.trackStage     = trackStage;
channel.msgStage       = msgStage;
channel.cnt_t          = cnt_t;
channel.cnt_m          = cnt_m;
channel.code           = code;
channel.timeIntMs      = timeIntMs;
channel.codeInt        = codeInt;
channel.pointInt       = pointInt;
channel.carrNco        = carrNco;
channel.codeNco        = codeNco;
channel.carrAcc        = carrAcc;
channel.carrFreq       = carrFreq;
channel.codeFreq       = codeFreq;
channel.remCarrPhase   = remCarrPhase;
channel.remCodePhase   = remCodePhase;
channel.carrCirc       = carrCirc;
channel.I_P0           = I_P;
channel.Q_P0           = Q_P;
channel.FLL            = FLL;
channel.PLL            = PLL;
channel.DLL            = DLL;
channel.bitSyncTable   = bitSyncTable;
channel.bitBuff        = bitBuff;
channel.frameBuff      = frameBuff;
channel.frameBuffPoint = frameBuffPoint;
channel.CN0            = CN0;
channel.Px             = P;

%% ���
I_Q = [I_P, I_E, I_L, Q_P, Q_E, Q_L];
disc = [codeError, codeSigma, carrError, carrSigma, freqError];
others = [carrAcc, sqrt(diag(P)')*3];

end