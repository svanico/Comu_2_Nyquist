function ej_3(cfg)

    %% ============================================================
    % EJERCICIO 3 - JITTER
    % =============================================================

    % Copiamos configuracion del main
    cfg_ej3 = cfg;

    % Cambios propios del Ejercicio 3
    cfg_ej3.EbNo            = 12;
    cfg_ej3.NTAPS_RRC       = 51;

    cfg_ej3.NTAPS_FIR       = 101;
    cfg_ej3.ch_bw           = 16e9;      % Distorsion moderada

    cfg_ej3.phase_offset     = 0;
    cfg_ej3.phase_tone_amp   = 0.1;

    cfg_ej3.dd_step          = 1e-3;
    cfg_ej3.leak             = 1e-7;

    cfg_ej3.rfd_gain         = 0;


    %% Valores a barrer

    Kp_vec = [1e-2 1e-3 1e-4 1e-5];

    f_jitter_vec = [400e3 500e3 750e3 1e6 1.25e6 1.5e6 1.75e6 ...
                    2e6 2.5e6 3e6 4e6 5e6 7.5e6 10e6 ...
                    20e6 50e6 100e6 300e6];

  % f_jitter_vec = [400e3 500e3 1e6 1.5e6  ...
  %                   2e6  3e6 4e6 7.5e6 10e6 ...
  %                   20e6 100e6 300e6];
  
    %% Matrices para guardar resultados
    % detector x Kp x frecuencia

    SNR_ref_dB       = zeros(2, length(Kp_vec));

    SNR_jitter_dB    = zeros(2, length(Kp_vec), ...
                             length(f_jitter_vec));

    penalidad_SNR_dB = zeros(2, length(Kp_vec), ...
                             length(f_jitter_vec));


    %% Transmisor
    % Es el mismo para todas las corridas

    rng(1);

    o_tx_s = transmisor_QAM(cfg_ej3);

    P_signal = mean(abs(o_tx_s.ak).^2);


    %% ============================================================
    % DETECTORES
    % detector = 1 -> 4th Power
    % detector = 2 -> DD
    % =============================================================

    %% Detector seleccionado desde el main
    detector = cfg_ej3.phase_detector;
    
    if detector == 1
        nombre_detector = '4th';
    elseif detector == 2
        nombre_detector = 'DD';
    else
        error('Para el Ejercicio 3, phase_detector debe ser 1 (4th) o 2 (DD)');
    end
        %% Barrido de Kp

        for i = 1:length(Kp_vec)

            cfg_temp = cfg_ej3;

            cfg_temp.phase_detector = detector;

            cfg_temp.Kp = Kp_vec(i);
            cfg_temp.Ki = cfg_temp.Kp/1500;


            fprintf('\n-----------------------------------------\n');
            fprintf('Detector %s | Kp = %.1e\n', ...
                    nombre_detector, cfg_temp.Kp);


            %% SNR DE REFERENCIA - SIN JITTER

            cfg_ref = cfg_temp;

            cfg_ref.en_c_error = 0;

            rng(2);

            o_canal_ref = channel(o_tx_s.o_tx, cfg_ref);

            o_rx_ref = Receiver( ...
                o_canal_ref, ...
                cfg_ref, ...
                o_tx_s.ak);


            % Medicion desde el inicio de DD del FFE
            idx_snr_ini = ...
                floor(cfg_ref.t4_ffe_dd/10) + 1;

            error_ref = ...
                o_rx_ref.error_base_log(idx_snr_ini:end);

            P_error_ref = mean(abs(error_ref).^2);

            SNR_ref_dB(detector,i) = ...
                10*log10(P_signal/P_error_ref);


            fprintf('SNR referencia = %.2f dB\n', ...
                    SNR_ref_dB(detector,i));


            %% BARRIDO DE FRECUENCIA DE JITTER

            for k = 1:length(f_jitter_vec)

                cfg_jit = cfg_temp;

                % Solo jitter de fase
                cfg_jit.en_c_error      = 1;
                cfg_jit.delta_freq      = 0;
                cfg_jit.phase_offset    = 0;
                cfg_jit.LW              = 0;
                cfg_jit.freq_fluct_amp  = 0;

                cfg_jit.phase_tone_amp  = 0.1;
                cfg_jit.phase_tone_freq = ...
                    f_jitter_vec(k);


                % Misma realizacion de ruido
                rng(2);

                o_canal = channel( ...
                    o_tx_s.o_tx, ...
                    cfg_jit);

                o_rx = Receiver( ...
                    o_canal, ...
                    cfg_jit, ...
                    o_tx_s.ak);


                % SNR
                idx_snr_ini = ...
                    floor(cfg_jit.t4_ffe_dd/10) + 1;

                error_ss = ...
                    o_rx.error_base_log(idx_snr_ini:end);

                P_error = mean(abs(error_ss).^2);


                SNR_jitter_dB(detector,i,k) = ...
                    10*log10(P_signal/P_error);


                penalidad_SNR_dB(detector,i,k) = ...
                    SNR_ref_dB(detector,i) ...
                    - SNR_jitter_dB(detector,i,k);


                fprintf(['f = %.3e Hz | ' ...
                         'SNR = %.2f dB | ' ...
                         'Penalidad = %.2f dB\n'], ...
                         f_jitter_vec(k), ...
                         SNR_jitter_dB(detector,i,k), ...
                         penalidad_SNR_dB(detector,i,k));

            end
        end
    


    %% Guardar todo en UN archivo

    archivo = sprintf('ej3_resultados_%s.mat', nombre_detector);
    
    save(archivo, ...
         'Kp_vec', ...
         'f_jitter_vec', ...
         'SNR_ref_dB', ...
         'SNR_jitter_dB', ...
         'penalidad_SNR_dB');
    
    fprintf('\nResultados guardados en %s\n', archivo);
end