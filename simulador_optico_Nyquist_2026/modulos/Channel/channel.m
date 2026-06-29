function [o_channel] = channel(i_channel, i_cfg_s)
%% Settings
    en_ch = i_cfg_s.en_ch_filter;
    en_n = i_cfg_s.en_n;
    pos_ruido = i_cfg_s.pos_n;
    M = i_cfg_s.M;
    Lsymbs = i_cfg_s.Lsymbs;
    BR = i_cfg_s.BR;
    NTAPS = i_cfg_s.NTAPS_FIR;
    % OVS = i_cfg_s.OVS;
    OVS = i_cfg_s.OVS.CH;
    fs = OVS * BR;
    delay = (NTAPS - 1) / 2;
    % fc = i_cfg_s.ch_bw / (fs / 2); 
    fc = 0.6;
    EbNo = i_cfg_s.EbNo;
    
    % Garantiza vector columna
    i_channel = i_channel(:); 

%% Procesamiento

    % Ruido
    if en_n
        n = AWGN_(M, EbNo, i_channel, OVS);
        n = n(:);
    else
        n = zeros(length(i_channel), 1);
    end

    if en_ch
        b = fir1(NTAPS - 1, fc); 
        
        if pos_ruido
            % Ruido coloreado
            s_in = i_channel + n; 
            s_out = filter(b, 1, [s_in; zeros(NTAPS-1, 1)]); 
            o_channel = s_out(delay+1 : end-delay); % Compensacion
        else
            % Ruido blanco
            s_out = filter(b, 1, [i_channel; zeros(NTAPS-1, 1)]); 
            s_filtered = s_out(delay+1 : end-delay); % Compensación
            o_channel = s_filtered + n; 
        end
        
    else
        o_channel = i_channel + n;
    end
    
end