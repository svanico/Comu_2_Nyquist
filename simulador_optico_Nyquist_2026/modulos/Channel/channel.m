function [o_channel] = channel(i_channel,i_cfg_s)

%%Settings
    en_ch = i_cfg_s.en_ch_filter;
    en_n = i_cfg_s.en_n;
    pos_ruido = i_cfg_s.pos_n;
    M = i_cfg_s.M;
    Lsymbs = i_cfg_s.Lsymbs;
    BR = i_cfg_s.BR;
    NTAPS = i_cfg_s.NTAPS_FIR;
    OVS = i_cfg_s.OVS;
    fs = OVS*BR;
    rolloff = i_cfg_s.rolloff;
    t0 = 0;
    delay = (NTAPS-1)/2;
    fc = i_cfg_s.ch_bw/(fs/2); %calculada para el FIR
    EbNo = i_cfg_s.EbNo;
    

%%Procesamiento

%Respuesta del canal
    if en_ch
        b = fir1(NTAPS,fc);  
    else
        b = 1;
    end
%Ruido
    if en_n
        n = AWGN_(M,EbNo,i_channel,OVS);
    else
        n = 0;
    end

%Señal de salida
    if pos_ruido
        s = i_channel + n; %ruido a la entrada
        o_channel = filter(b,1,[s;zeros(NTAPS-1,1)]); %padding de ceros
        o_channel = o_channel(delay+1:end); %elimina retardo de grupo

    else
        s = filter(b,1,[i_channel;zeros(NTAPS-1,1)]); %padding de ceros
        o_channel = o_channel(delay+1:end); %elimina retardo de grupo
        o_channel = o_channel + n; %ruido a la salida


        %en la 43 no seria o_channel = s() ? pq si pos_ruido no se cumple o
        %channel no esta definido, o si?
end

