function [o_data_tx] = transmisor_QAM(i_cfg_s)

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
    o_data_tx.ak = QAM_gen(M,Lsymbs);
    o_data_tx.ak_ovs = oversampler(OVS,Lsymbs,o_data_tx.ak); 
    [~, rrc] = root_raised_cosine(BR,fs,rolloff,NTAPS,t0);
    rrc = rrc ./ norm(rrc)* sqrt(OVS);
    o_data_tx.rrc=rrc;
    
    Lrrc = length(rrc);
    delay = floor((Lrrc-1)/2); %calculo el delay para el largo del rrc

    tx  = filter(rrc,1,[o_data_tx.ak_ovs; zeros(Lrrc-1,1)]); %padding de ceros para la cola del filtro
                                                            % esto tendria
                                                            % que ser para
                                                            % el largo del
                                                            % filtro,
                                                            % cambie NTAPS
                                                            % por Lrrc
    o_data_tx.o_tx = tx(delay+1:length(tx)-delay); %elimina retardo de grupo

end

