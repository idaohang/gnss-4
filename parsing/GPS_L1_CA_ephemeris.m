function ephemeris = GPS_L1_CA_ephemeris(bits)
% ��������1500���ص������ĺ���һ�������λ����1��������GPS����

ephemeris = zeros(26,1);

% ��ƽ��ת
bits = -bits(62) * bits;

% ת���ɶ������ַ���
bits = bits>0;
bits = dec2bin(bits)';

% ��¼D30��ɾ��ǰ��������
D30 = bits(2);
bits(1:2) = [];

gpsPi = 3.1415926535898; 

for k=0:4
    subframe = bits(k*300+(1:300)); %ȡһ����֡
    
    % ����У��������֡�е�ÿ��������ƽ��ת
    for m=1:10
        subframe(30*m+(-29:0)) = GPS_L1_CA_bitsFlip(subframe(30*m+(-29:0)), D30);
        D30 = subframe(30*m);
    end
    
    subframeID = bin2dec(subframe(50:52)); %��֡ID
    
    switch subframeID
        case 1
            TOW = (bin2dec(subframe(31:47))-1)*6; %------>
            week = bin2dec(subframe(61:70));
            IODC = bin2dec([subframe(83:84),subframe(211:218)]);
            tGD = twosComp2dec(subframe(197:204)) * 2^(-31);
            toc = bin2dec(subframe(219:234)) * 2^4;
            af2 = twosComp2dec(subframe(241:248)) * 2^(-55);
            af1 = twosComp2dec(subframe(249:264)) * 2^(-43);
            af0 = twosComp2dec(subframe(271:292)) * 2^(-31);
        case 2
            IODE = bin2dec(subframe(61:68));
            Crs = twosComp2dec(subframe(69:84)) * 2^(-5);
            dn = twosComp2dec(subframe(91:106)) * 2^(-43) * gpsPi;
            M0 = twosComp2dec([subframe(107:114),subframe(121:144)]) * 2^(-31) * gpsPi;
            Cuc = twosComp2dec(subframe(151:166)) * 2^(-29);
            e = bin2dec([subframe(167:174),subframe(181:204)]) * 2^(-33);
            Cus = twosComp2dec(subframe(211:226)) * 2^(-29);
            sqa = bin2dec([subframe(227:234),subframe(241:264)]) * 2^(-19);
            toe = bin2dec(subframe(271:286)) * 2^4;
        case 3
            Cic = twosComp2dec(subframe(61:76)) * 2^(-29);
            Omega0 = twosComp2dec([subframe(77:84),subframe(91:114)]) * 2^(-31) * gpsPi;
            Cis = twosComp2dec(subframe(121:136)) * 2^(-29);
            i0 = twosComp2dec([subframe(137:144),subframe(151:174)]) * 2^(-31) * gpsPi;
            Crc = twosComp2dec(subframe(181:196)) * 2^(-5);
            omega = twosComp2dec([subframe(197:204),subframe(211:234)]) * 2^(-31) * gpsPi;
            Omega_dot = twosComp2dec(subframe(241:264)) * 2^(-43) * gpsPi;
            i_dot = twosComp2dec(subframe(279:292)) * 2^(-43) * gpsPi;
        case 4
        case 5
        otherwise
    end
end

flags = 0;

ephemeris(1)  = week;
ephemeris(2)  = IODC;
ephemeris(3)  = IODE;
ephemeris(4)  = TOW;
ephemeris(5)  = toc;
ephemeris(6)  = toe;
ephemeris(7)  = tGD;
ephemeris(8)  = af2;
ephemeris(9)  = af1;
ephemeris(10) = af0;
ephemeris(11) = Crs;
ephemeris(12) = dn;
ephemeris(13) = M0;
ephemeris(14) = Cuc;
ephemeris(15) = e;
ephemeris(16) = Cus;
ephemeris(17) = sqa;
ephemeris(18) = Cic;
ephemeris(19) = Omega0;
ephemeris(20) = Cis;
ephemeris(21) = i0;
ephemeris(22) = Crc;
ephemeris(23) = omega;
ephemeris(24) = Omega_dot;
ephemeris(25) = i_dot;
ephemeris(26) = flags;

end