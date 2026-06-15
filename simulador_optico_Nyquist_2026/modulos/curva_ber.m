function [ber_sim, errors_sim] = curva_ber(cfg_s, EbNo_BER)
    % vectores
    ber_sim = zeros(size(EbNo_BER));
    errors_sim = zeros(size(EbNo_BER));

    % --- TRANSMISOR 
    o_tx_s = transmisor_QAM(cfg_s);
    ak     = o_tx_s.ak;
    i_canal = o_tx_s.o_tx;

    % --- BUCLE DE SIMULACIÓN ---
    disp('Iniciando simulación de curva BER...');
    for idx = 1:length(EbNo_BER)
        % Actualizar EbNo actual
        cfg_s.EbNo = EbNo_BER(idx);
        
        % Canal
        o_canal = channel(i_canal, cfg_s);
        
        % Receptor
        o_rx = Receiver(o_canal, cfg_s);
        
        % Ber checker 
        [ber, errors] = BER_checker(o_rx.ak_hat, ak, cfg_s.M, 0);
        ber_sim(idx)    = ber;
        errors_sim(idx) = errors;
        
        % Mostrar progreso por consola
        fprintf('Eb/No = %2d dB | BER = %e | Errores = %d\n', cfg_s.EbNo, ber, errors);
    end

    % --- GRÁFICO DE LA CURVA ---
    ber_teorica = berawgn(EbNo_BER, 'qam', cfg_s.M);

    figure('Name', 'Curva de Rendimiento del Sistema');
    semilogy(EbNo_BER, ber_teorica, 'r-', 'LineWidth', 2); hold on;
    semilogy(EbNo_BER, ber_sim, 'bo--', 'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'MarkerSize', 6);
    grid on;
    xlabel('E_b/N_0 (dB)');
    ylabel('Bit Error Rate (BER)');
    title(sprintf('Curva de BER para %d-QAM (%d Símbolos)', cfg_s.M, cfg_s.Lsymbs));
    legend('Teórica (AWGN)', 'Simulada', 'Location', 'best');
    ylim([1e-6 1]);
end