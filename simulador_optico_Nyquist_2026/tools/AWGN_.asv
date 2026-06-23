function [n_v] = AWGN_(M,EbNo,data,OVS)

    % Generación de ruido
    k = log2(M);
    EbNo_veces = 10^(EbNo/10);
    SNR_slc = k*EbNo_veces;
    SNR_ch = SNR_slc/OVS;
    Ps = var(data);   
    Pn = Ps / SNR_ch;
    
        n_v = sqrt(Pn/2).*(randn(size(data)) + 1j.*randn(size(data)));

end

