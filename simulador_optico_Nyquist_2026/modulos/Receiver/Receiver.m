function [o_data_rx] = Receiver(i_rx,i_cfg_s)
%Settings
    M = i_cfg_s.M;
    Lsymbs = i_cfg_s.Lsymbs;
    BR = i_cfg_s.BR;
    NTAPS = i_cfg_s.NTAPS_RRC;
    OVS = i_cfg_s.OVS;
    fs = OVS*BR;
    rolloff = i_cfg_s.rolloff;
    t0 = 0;

%Procesamiento
    r = i_rx;
    [~, rrc] = root_raised_cosine(BR,fs,rolloff,NTAPS,t0);
    rrc = rrc ./ norm(rrc) * sqrt(OVS);
    
    Lrrc = length(rrc);
    delay = floor((Lrrc-1)/2); %calculo el delay para el largo del rrc

    y = filter(rrc,1,[r; zeros(Lrrc-1,1)]); %padding de ceros para la cola del filtro, con el tamaño del mismo
    o_data_rx.y = y(delay+1:end-delay)/OVS; %elimina retardo de grupo

    o_data_rx.o_dws = downsampler(OVS,o_data_rx.y);


%Slicer
    o_data_rx.ak_hat = slicer(o_data_rx.o_dws,M);

end



