function ej_2(cfg)
    %% ============================================================
    % EJERCICIO 2 - Penalidad de SNR
    % =============================================================

    % Copiamos configuracion del main
    cfg_ej2 = cfg;

    %% Cambios propios del Ejercicio 2
    cfg_ej2.M               = 16;
    cfg_ej2.rolloff         = 0.6;
    cfg_ej2.Lsymbs          = 1e6;

    cfg_ej2.en_ch_filter    = 1;
    cfg_ej2.en_n            = 1;
    cfg_ej2.pos_n           = 0;

    cfg_ej2.NTAPS_RRC       = 101;
    cfg_ej2.NTAPS_FIR       = 51;
    cfg_ej2.NTAPS_ffe       = 51;

    % En el Ejercicio 2 no queremos errores de portadora
    cfg_ej2.en_c_error      = 0;
    cfg_ej2.delta_freq      = 0;
    cfg_ej2.phase_offset    = 0;
    cfg_ej2.LW              = 0;
    cfg_ej2.freq_fluct_amp  = 0;
    cfg_ej2.freq_fluct_freq = 0;
    cfg_ej2.phase_tone_amp  = 0;
    cfg_ej2.phase_tone_freq = 0;

    % Apago recuperación de portadora para aislar el efecto del canal
    cfg_ej2.en_carrier_recovery = 1;
    cfg_ej2.phase_detector      = 0;
    cfg_ej2.rfd_gain            = 1e-4;

    %% Valores a barrer

    % EbNo_BER = 8:1:15;
      EbNo_BER = 9:1:14;

    L_vec    = 1e6 * ones(size(EbNo_BER));

    ch_bw_vec = [0 17.75e9 16e9 15.5e9];
    ch_names  = {'Impulso', 'Leve', 'Moderada', 'Agresiva'};

    Nch = length(ch_bw_vec);
    Ne  = length(EbNo_BER);

    ber_sim    = zeros(Nch, Ne);
    errors_sim = zeros(Nch, Ne);

    %% Simulación BER para cada canal

    for ch_idx = 1:Nch

        fprintf('\n=====================================\n');
        fprintf('Canal: %s\n', ch_names{ch_idx});
        fprintf('=====================================\n');

        for idx = 1:Ne

            cfg_temp = cfg_ej2;

            cfg_temp.EbNo   = EbNo_BER(idx);
            cfg_temp.Lsymbs = L_vec(idx);

            % Actualizo timers porque dependen de Lsymbs
            cfg_temp.t1_rfd    = fix(cfg_temp.t1_rfd_frac    * cfg_temp.Lsymbs);
            cfg_temp.t2_fcr_v4 = fix(cfg_temp.t2_fcr_v4_frac * cfg_temp.Lsymbs);
            cfg_temp.t3_fcr_dd = fix(cfg_temp.t3_fcr_dd_frac * cfg_temp.Lsymbs);
            cfg_temp.t4_ffe_dd = fix(cfg_temp.t4_ffe_dd_frac * cfg_temp.Lsymbs);

            % Configuración del canal
            if ch_idx == 1
                cfg_temp.en_ch_filter = 0;      % Canal impulso
            else
                cfg_temp.en_ch_filter = 1;
                cfg_temp.ch_bw = ch_bw_vec(ch_idx);
            end

            rng(1);

            % Transmisor
            o_tx_s = transmisor_QAM(cfg_temp);

            % Canal
            o_canal = channel(o_tx_s.o_tx, cfg_temp);

            % Receptor
            o_rx = Receiver(o_canal, cfg_temp, o_tx_s.ak);

            % BER checker
            [ber, errors] = BER_checker( ...
                o_rx.ak_hat_fixed, ...
                o_rx.ak_tx_aligned, ...
                cfg_temp.M, ...
                0);

            ber_sim(ch_idx, idx)    = ber;
            errors_sim(ch_idx, idx) = errors;

            % fprintf('EbNo = %.1f dB | BER = %.3e | errores = %d | MSE = %.2f dB\n', ...
            %         cfg_temp.EbNo, ber, errors, o_rx.MSE);

        end
    end

    %% Curva teórica

    ber_teorica = berawgn(EbNo_BER, 'qam', cfg_ej2.M);

    %% Penalidad a BER fija

    BER_obj = 1e-3;            %BER 10e-3    

   % Cruce de la curva teorica, solo como referencia informativa
    EbNo_teorica = find_ebno_at_ber(EbNo_BER, ber_teorica, BER_obj);
    
    % Cruce de cada curva simulada
    EbNo_cross = NaN(Nch, 1);
    
    for ch_idx = 1:Nch
    
        EbNo_cross(ch_idx) = find_ebno_at_ber( ...
            EbNo_BER, ...
            ber_sim(ch_idx,:), ...
            BER_obj);
    
    end
    
    % Tomo como referencia el caso impulso
    EbNo_ref = EbNo_cross(1);
    
    % Penalidad respecto del canal impulso
    penalidad_dB = EbNo_cross - EbNo_ref;
    %% Mostrar resultados por consola
    % 
    % fprintf('\n=====================================\n');
    % fprintf('Penalidad de SNR a BER = %.1e\n', BER_obj);
    % fprintf('=====================================\n');
    % fprintf('Referencia teorica: EbNo = %.3f dB\n', EbNo_teorica);
    % fprintf('Referencia impulso : EbNo = %.3f dB\n\n', EbNo_ref);
    % 
    % for ch_idx = 1:Nch
    %     fprintf('%-9s | EbNo cruce = %.3f dB | Penalidad = %.3f dB\n', ...
    %             ch_names{ch_idx}, ...
    %             EbNo_cross(ch_idx), ...
    %             penalidad_dB(ch_idx));
    % end

    %% Gráfico BER con línea horizontal
    % 
    figure('Name','Ejercicio 2 - BER');
    semilogy(EbNo_BER, ber_teorica, 'k-', ...
        'LineWidth', 2, ...
        'DisplayName', 'Teórica 16-QAM');
    hold on;

    for ch_idx = 1:Nch
        semilogy(EbNo_BER, ber_sim(ch_idx,:), 'o--', ...
            'LineWidth', 1.3, ...
            'DisplayName', ch_names{ch_idx});
    end

    yline(BER_obj, 'k--', sprintf('BER = %.0e', BER_obj), 'LineWidth', 1.2);


    grid on;
    xlabel('E_b/N_0 [dB]');
    ylabel('BER');
    title('BER vs E_b/N_0 - 16-QAM');
    legend('Location','best');
    ylim([1e-5 2e-2]);

    %% Gráfico de penalidad

    figure('Name','Ejercicio 2 - Penalidad de SNR');

    x_cases = 1:Nch;

    semilogx(x_cases, penalidad_dB, '-o', ...
         'LineWidth', 1.8, ...
         'MarkerSize', 8);

%chequear si cambiando el ancho de banda es suficiente y queda bien

    grid on;
    xticks(x_cases);
    xticklabels(ch_names);

    xlabel('Caso de canal');
    ylabel('Penalidad de SNR [dB]');
    title(sprintf('Penalidad de SNR a BER = %.0e', BER_obj));

    ylim([0 max(penalidad_dB)*1.2]);


%% ============================================================
% Comparación temporal de taps del FFE
% =============================================================

% Uso un EbNo fijo para comparar la respuesta final del ecualizador
EbNo_taps = cfg_ej2.EbNo;

htaps_mat = zeros(cfg_ej2.NTAPS_ffe, Nch);

for ch_idx = 1:Nch

    cfg_temp = cfg_ej2;

    cfg_temp.EbNo   = EbNo_taps;
    cfg_temp.Lsymbs = cfg_ej2.Lsymbs;

    % Actualizo timers porque dependen de Lsymbs
    cfg_temp.t1_rfd    = fix(cfg_temp.t1_rfd_frac    * cfg_temp.Lsymbs);
    cfg_temp.t2_fcr_v4 = fix(cfg_temp.t2_fcr_v4_frac * cfg_temp.Lsymbs);
    cfg_temp.t3_fcr_dd = fix(cfg_temp.t3_fcr_dd_frac * cfg_temp.Lsymbs);
    cfg_temp.t4_ffe_dd = fix(cfg_temp.t4_ffe_dd_frac * cfg_temp.Lsymbs);

    % Configuración del canal
    if ch_idx == 1
        cfg_temp.en_ch_filter = 0;      % Canal impulso
    else
        cfg_temp.en_ch_filter = 1;
        cfg_temp.ch_bw = ch_bw_vec(ch_idx);
    end

    rng(1);

    % Transmisor
    o_tx_s = transmisor_QAM(cfg_temp);

    % Canal
    o_canal = channel(o_tx_s.o_tx, cfg_temp);

    % Receptor
    o_rx = Receiver(o_canal, cfg_temp, o_tx_s.ak);

    % Guardo taps finales
    htaps_mat(:, ch_idx) = o_rx.htaps(:);

end

%% Figura comparativa de taps en tiempo

tap_axis = 1:cfg_ej2.NTAPS_ffe;

figure('Name','Ejercicio 2 - Taps FFE real e imaginario');

subplot(2,1,1);
hold on;

for ch_idx = 1:Nch
    plot(tap_axis, real(htaps_mat(:,ch_idx)), '-o', ...
         'LineWidth', 1.3, ...
         'MarkerSize', 4, ...
         'DisplayName', ch_names{ch_idx});
end

grid on;
xlabel('Índice de tap');
ylabel('Parte real');
title(sprintf('Parte real de los taps del FFE - EbNo = %.1f dB', EbNo_taps));
legend('Location','best');

subplot(2,1,2);
hold on;

for ch_idx = 1:Nch
    plot(tap_axis, imag(htaps_mat(:,ch_idx)), '-o', ...
         'LineWidth', 1.3, ...
         'MarkerSize', 4, ...
         'DisplayName', ch_names{ch_idx});
end

grid on;
xlabel('Índice de tap');
ylabel('Parte imaginaria');
title(sprintf('Parte imaginaria de los taps del FFE - EbNo = %.1f dB', EbNo_taps));
legend('Location','best');


%% ============================================================
% Respuesta en frecuencia del FFE normalizada en DC
% =============================================================

NFFT = 4096;
Fs_ffe = cfg_ej2.BR * cfg_ej2.OVS.DSP;   % frecuencia de muestreo del FFE
f = (0:NFFT/2-1) * Fs_ffe/NFFT;          % eje frecuencia positiva

figure('Name','Ejercicio 2 - Respuesta en frecuencia FFE normalizada');

hold on;

for ch_idx = 1:Nch

    Hffe = fft(htaps_mat(:,ch_idx), NFFT);
    Hffe_pos = Hffe(1:NFFT/2);

    % Normalización en DC
    Hffe_norm = Hffe_pos ./ (abs(Hffe_pos(1)) + eps);

    Hffe_dB = 20*log10(abs(Hffe_norm) + 1e-12);

    plot(f/1e9, Hffe_dB, ...
         'LineWidth', 1.5, ...
         'DisplayName', ch_names{ch_idx});

end

grid on;
xlabel('Frecuencia [GHz]');
ylabel('|H_{FFE}(f)| normalizada en DC [dB]');
title('Respuesta en frecuencia final del FFE');

xlim([0 Fs_ffe/2/1e9]);     % 0 a 32 GHz para OVS.DSP = 2
ylim([-30 10]);             % ajustable según cómo quede
legend('Location','best');



    %% Guardar resultados

    save('ej2_penalidad_snr.mat', ...
         'EbNo_BER', ...
         'ber_teorica', ...
         'ber_sim', ...
         'errors_sim', ...
         'ch_bw_vec', ...
         'ch_names', ...
         'BER_obj', ...
         'EbNo_ref', ...
         'EbNo_cross', ...
         'penalidad_dB', ...
         'htaps_mat', ...
        'EbNo_taps');

    fprintf('\nResultados guardados en ej2_penalidad_snr.mat\n');

end


%% ============================================================
% Función auxiliar local
% =============================================================
function EbNo_cross = find_ebno_at_ber(EbNo_vec, ber_vec, BER_obj)

    EbNo_vec = EbNo_vec(:);
    ber_vec  = ber_vec(:);

    valid = isfinite(ber_vec) & ber_vec > 0;

    EbNo_vec = EbNo_vec(valid);
    ber_vec  = ber_vec(valid);

    x = log10(ber_vec);
    y = EbNo_vec;

    [x_sort, idx_sort] = sort(x);
    y_sort = y(idx_sort);

    x_obj = log10(BER_obj);

    if x_obj < min(x_sort) || x_obj > max(x_sort)

        EbNo_cross = NaN;

        warning('La curva no cruza BER = %.1e dentro del rango simulado.', BER_obj);

        return;

    end

    EbNo_cross = interp1(x_sort, y_sort, x_obj, 'linear');










end
