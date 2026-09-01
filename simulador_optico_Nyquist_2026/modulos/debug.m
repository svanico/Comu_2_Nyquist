function debug(cfg, tx, ch, rx)
    % Si ambos enables están apagados, salimos inmediatamente
    if ~cfg.en_plots_tx && ~cfg.en_plots_rx
        return; 
    end
    
    fprintf('\n--- Abriendo Dashboard de Depuración ---\n');
    
    % Variables de entorno globales
    OVS_CH  = cfg.OVS.CH;
    OVS_DSP = cfg.OVS.DSP;
    fs_ch   = OVS_CH * cfg.BR;
    fs_dsp  = OVS_DSP * cfg.BR;
    FRAME_LOG = 10; % Tasa de decimación de los logs
    
    %% =========================================================================
    %                               GRÁFICOS TX
    % ==========================================================================
    if cfg.en_plots_tx
        figure('Name', '1. Transmisión y Canal', 'Color', 'w', 'Position', [50, 50, 1200, 600]);
        N_symbs_plot = 50; 
        N_samps_plot = N_symbs_plot * OVS_CH;
        
        eje_sym = 1:N_symbs_plot;
        eje_samp = (1:N_samps_plot) / OVS_CH; 
        
        subplot(2,2,1);
        stem(eje_sym, real(tx.ak(1:N_symbs_plot)), 'filled', 'Color', '#0072BD', 'LineWidth', 1.5);
        grid on; box on;
        xlabel('Índice de Símbolo (n)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Símbolos Tx (Re\{ak\})');
        
        subplot(2,2,3);
        stem(eje_sym, imag(tx.ak(1:N_symbs_plot)), 'filled', 'Color', '#D95319', 'LineWidth', 1.5);
        grid on; box on;
        xlabel('Índice de Símbolo (n)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Símbolos Tx (Im\{ak\})');
        
        subplot(2,2,2);
        plot(eje_samp, real(tx.o_tx(1:N_samps_plot)), 'Color', '#0072BD', 'LineWidth', 1.5);
        grid on; box on;
        xlabel('Tiempo (Normalizado a Ts)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Señal Transmitida (Filtro Tx - Parte Real)');
        
        subplot(2,2,4);
        plot(eje_samp, real(ch(1:N_samps_plot)), 'Color', '#7E2F8E', 'LineWidth', 1);        
        grid on; box on;
        xlabel('Tiempo (Normalizado a Ts)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Señal Recibida (Canal - Parte Real)');
    end
    
    %% =========================================================================
    %                               GRÁFICOS RX
    % ==========================================================================
    if cfg.en_plots_rx
        
        % ----------------------------------------------------------------------
        % 1. PSD (Densidad Espectral de Potencia)
        % ----------------------------------------------------------------------
        if cfg.debug_psd
            NFFT = 4096;
            win_len = min(2048, length(tx.o_tx));
            win = hamming(win_len);
            overlap = floor(win_len/2);
            
            [Ptx, f_ch_psd] = pwelch(tx.o_tx, win, overlap, NFFT, fs_ch, 'centered');
            [Pch, ~]        = pwelch(ch, win, overlap, NFFT, fs_ch, 'centered');
            [Prx, ~]        = pwelch(rx.y, win, overlap, NFFT, fs_ch, 'centered');
            
            H_ffe = fftshift(fft(rx.htaps, NFFT));
            f_dsp_psd = linspace(-fs_dsp/2, fs_dsp/2, NFFT);
            
            figure('Name','1. Dominio de Frecuencia (PSD)', 'Color', 'w', 'Position', [100, 100, 800, 500]);
            
            plot(f_ch_psd/1e9, 10*log10(Ptx./max(Ptx)), 'LineWidth', 1.3, 'DisplayName', 'Salida TX');
            hold on;
            plot(f_ch_psd/1e9, 10*log10(Pch./max(Pch)), 'LineWidth', 1.3, 'DisplayName', 'Salida canal');
            plot(f_ch_psd/1e9, 10*log10(Prx./max(Prx)), 'LineWidth', 1.3, 'DisplayName', 'Filtro anti-alias RX');
            
            plot(f_dsp_psd/1e9, 20*log10(abs(H_ffe)./max(abs(H_ffe))), ...
                 'k--', 'LineWidth', 2.5, 'DisplayName', 'Respuesta FFE (normalizada)');
            
            grid on; box on;
            xlim([0, 40]); % Semieje positivo hasta 40 GHz
            ylim([-30, 5]); 
            xlabel('Frecuencia [GHz]', 'FontWeight', 'bold');
            ylabel('PSD normalizada [dB]', 'FontWeight', 'bold');
            title(sprintf('PSD (M=%d, Eb/No=%.1fdB)', cfg.M, cfg.EbNo));
            legend('Location','best');
        end
        
        
        % ----------------------------------------------------------------------
        % 3. ECUALIZADOR (Convergencia, SNR, evolución taps, rta temporal y frecuencial)
        % ----------------------------------------------------------------------
        figure('Name', '3. Dinámica del Ecualizador FFE', 'Color', 'w', 'Position', [100, 100, 1400, 700]);
        
        subplot(2,3,1);
        N_filt = 100;
        mse_smooth = 10*log10(filter(ones(N_filt,1)./N_filt, 1, abs(rx.error_base_log).^2));
        plot(mse_smooth, 'LineWidth', 2, 'Color', '#0072BD');
        grid on; box on;
        xline(cfg.t4_ffe_dd / FRAME_LOG, 'r--', 'Switch a DD', 'LabelVerticalAlignment', 'bottom');
        xlabel('Iteraciones (x10)', 'FontWeight', 'bold'); 
        ylabel('MSE [dB]', 'FontWeight', 'bold');
        title(sprintf('Evolución del MSE'));
        
        subplot(2,3,2);
        P_signal = mean(abs(tx.ak).^2);
        snr_est = 10*log10(P_signal ./ filter(ones(N_filt,1)./N_filt, 1, abs(rx.error_base_log).^2));
        plot(snr_est, 'LineWidth', 2, 'Color', '#EDB120');
        grid on; box on;
        xline(cfg.t4_ffe_dd / FRAME_LOG, 'r--', 'Switch a DD', 'LabelVerticalAlignment', 'bottom');
        xlabel('Iteraciones (x10)', 'FontWeight', 'bold'); 
        ylabel('SNR Estimada [dB]', 'FontWeight', 'bold');
        title(sprintf('Relación Señal-Ruido (Final: %.2f dB)', snr_est(end)));
        
        subplot(2,3,4);
        htaps_finales = rx.htaps; 
        eje_taps = 1:cfg.NTAPS_ffe;
        stem(eje_taps, real(htaps_finales), 'filled', 'LineWidth', 1.5, ...
             'MarkerSize', 5, 'Color', '#0072BD', 'MarkerFaceColor', '#0072BD', 'DisplayName', 'Real');
        hold on;
        stem(eje_taps, imag(htaps_finales), 'filled', 'LineWidth', 1.5, ...
             'MarkerSize', 5, 'Color', '#D95319', 'MarkerFaceColor', '#D95319', 'DisplayName', 'Imaginario');
        grid on; box on;
        idx_central = floor(cfg.NTAPS_ffe/2) + 1;
        plot(idx_central, real(htaps_finales(idx_central)), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5, 'HandleVisibility', 'off');
        plot(idx_central, imag(htaps_finales(idx_central)), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5, 'HandleVisibility', 'off');
        hold off;
        xlabel('Índice del Tap', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Forma Temporal (Taps)');
        legend('Location', 'best');
             
        subplot(2,3,3);
        N_fft = 1024;
        H_ffe_resp = fft(htaps_finales, N_fft);
        H_ffe_resp = H_ffe_resp(1:N_fft/2); 
        f_norm = linspace(0, 0.5, N_fft/2);
        
        % Cálculo de ganancia absoluta original (sin división por max)
        H_ffe_resp_db = 20*log10(abs(H_ffe_resp) + eps); 
        
        plot(f_norm, H_ffe_resp_db, 'LineWidth', 2, 'Color', '#7E2F8E');
        grid on; box on;
        
        % Límite inferior fijo en -30 dB, límite superior dinámico (pico + 5 dB)
        ylim([-30, max(H_ffe_resp_db) + 5]); 
        
        xlabel('Frecuencia normalizada (f/f_s)', 'FontWeight', 'bold');
        ylabel('Magnitud [dB]', 'FontWeight', 'bold');
        title('Respuesta en Frecuencia');
        
        taps_to_plot = rx.htaps_log(:, 1:20:end);
        iter_axis = (1:size(taps_to_plot, 2)) * FRAME_LOG * 20;
        taps_matrix = taps_to_plot.'; 
        
        subplot(2,3,5);
        plot(iter_axis, real(taps_matrix), 'LineWidth', 1);
        grid on; box on;
        xline(cfg.t4_ffe_dd, 'r--', 'Switch a DD');
        xlabel('Iteraciones', 'FontWeight', 'bold');
        ylabel('Re{h(n)}', 'FontWeight', 'bold');
        title('Evolución (Real)');
        
        subplot(2,3,6);
        plot(iter_axis, imag(taps_matrix), 'LineWidth', 1);
        grid on; box on;
        xline(cfg.t4_ffe_dd, 'r--', 'Switch a DD');
        xlabel('Iteraciones', 'FontWeight', 'bold');
        ylabel('Im{h(n)}', 'FontWeight', 'bold');
        title('Evolución (Imaginaria)');
             
% ----------------------------------------------------------------------
        % 4. RECUPERACIÓN DE PORTADORA (PLL Y CONSTELACIONES)
        % ----------------------------------------------------------------------
        if cfg.en_carrier_recovery
            figure('Name', '4. Recuperación de Portadora (PLL)', 'Color', 'w', 'Position', [150, 200, 1200, 600]);
            
            symb_axis = (1:length(rx.phase_integral_log)) .* FRAME_LOG;
            
            % --- Subplot 1 (Arriba Izquierda): Trayectoria de Fase ---
            subplot(2,3,1);
            %fase_plot = wrapToPi(rx.phase_acc_log);
            fase_plot = rx.phase_acc_log;
            plot(symb_axis, fase_plot, 'LineWidth', 1.5, 'Color', '#77AC30');
            grid on; hold on;
            xline(cfg.t2_fcr_v4, 'r--', 'FCR ON', 'LabelVerticalAlignment', 'bottom');
            %ylim([-pi, pi]);
            %yticks([-pi, -pi/2, 0, pi/2, pi]);
            %yticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});
            xlabel('Símbolos', 'FontWeight', 'bold'); 
            ylabel('Ángulo de Corrección [rad]', 'FontWeight', 'bold');
            title('Trayectoria de Fase (NCO)');
            
            % --- Subplot 2 (Arriba Centro): Seguimiento de Frecuencia ---
            subplot(2,3,2);
            freq_est_MHz = rx.phase_integral_log .* cfg.BR ./ (2*pi) ./ 1e6;
            plot(symb_axis, freq_est_MHz, 'LineWidth', 2, 'Color', '#A2142F');
            grid on; hold on;
            %if isfield(cfg, 'delta_freq')
            %    yline(cfg.delta_freq / 1e6, 'k--', 'Offset Real', 'LineWidth', 1.5);
            end
            xline(cfg.t2_fcr_v4, 'r--', 'FCR ON', 'LabelVerticalAlignment', 'bottom');
            xlabel('Símbolos', 'FontWeight', 'bold'); 
            ylabel('Offset Estimado [MHz]', 'FontWeight', 'bold');
            title('Seguimiento de Frecuencia');

            % --- Subplot 3 (Arriba Derecha): Rama I Temporal ---
            subplot(2,3,3);
            plot(real(rx.slicer_in_log), '.', 'Color', '#0072BD', 'MarkerSize', 1);
            grid on;
            xlabel('Símbolos', 'FontWeight', 'bold');
            ylabel('Parte Real', 'FontWeight', 'bold');
            title('Entrada al Slicer - Rama I');

            % Variables para Constelaciones
            N_tail = min(2000, length(rx.slicer_in_log));
            slicer_in = rx.slicer_in_log;
            phase_acc = rx.phase_acc_log;
            ffe_out = slicer_in .* exp(1j * phase_acc);
            
            % --- Subplot 4 (Abajo Izquierda): Constelación ANTES ---
            subplot(2,3,4);
            scatter(real(ffe_out(end-N_tail:end)), imag(ffe_out(end-N_tail:end)), 10, 'filled', 'MarkerFaceColor', '#7E2F8E', 'MarkerFaceAlpha', 0.6);
            grid on; axis square;
            xlabel('In-Phase (I)', 'FontWeight', 'bold');
            ylabel('Quadrature (Q)', 'FontWeight', 'bold');
            title('ANTES del FCR (Salida FFE)');
            
            % --- Subplot 5 (Abajo Centro): Constelación DESPUÉS ---
            subplot(2,3,5);
            scatter(real(slicer_in(end-N_tail:end)), imag(slicer_in(end-N_tail:end)), 10, 'filled', 'MarkerFaceColor', '#D95319', 'MarkerFaceAlpha', 0.6);
            grid on; axis square;
            xlabel('In-Phase (I)', 'FontWeight', 'bold');
            ylabel('Quadrature (Q)', 'FontWeight', 'bold');
            title('DESPUÉS del FCR (Entrada Slicer)');
            
            % --- Subplot 6 (Abajo Derecha): Rama Q Temporal ---
            subplot(2,3,6);
            plot(imag(rx.slicer_in_log), '.', 'Color', '#D95319', 'MarkerSize', 1);
            grid on;
            xlabel('Símbolos', 'FontWeight', 'bold');
            ylabel('Parte Imaginaria', 'FontWeight', 'bold');
            title('Entrada al Slicer - Rama Q');
            
            % ------------------------------------------------------------------
            % 5. FIGURA INDEPENDIENTE PARA JITTER TRANSFER
            % ------------------------------------------------------------------
            if isfield(cfg, 'Kp') && isfield(cfg, 'Ki')
                figure('Name', '5. Jitter Transfer FCR', 'Color', 'w', 'Position', [200, 250, 600, 450]);
                
                Kp = cfg.Kp; 
                Ki = cfg.Ki; 
                BR = cfg.BR;
              
                n_freq_pos = 2^16;
                n_freq_frac = 2^16;
                n_v = [0, logspace(-log10(n_freq_frac), log10(n_freq_pos), n_freq_pos+n_freq_frac-1)];
                
                f_v = n_v * BR / 2 / n_freq_pos;
                wd_v = n_v * pi / n_freq_pos;
                
                G_th_v = (Kp + Ki .* 1./(1 - exp(-1j.*wd_v))) .* 1./(1 - exp(-1j.*wd_v));
                H_th_v = G_th_v ./ (1 + G_th_v);
                H_th_db_v = 20*log10(abs(H_th_v));
                
                semilogx(f_v, H_th_db_v, '-', 'Linewidth', 2, 'Color', '#0072BD');
                hold on;
                plot(xlim, [-3 -3], '-.m', 'Linewidth', 1.5, 'DisplayName', '-3 dB');
                grid on; 
                xlim([1e6, 1e8]);
                ylim([-15, 5]); 
                
                xlabel('Frecuencia [Hz]', 'FontWeight', 'bold');
                ylabel('Amplitud [dB]', 'FontWeight', 'bold');
                title(sprintf('Jitter Transfer (BR=%.2f GBd)', BR/1e9));
                leg_str = sprintf('Kp = %.2e\nKi = %.2e', Kp, Ki);
                legend(leg_str, '-3 dB', 'Location', 'southwest', 'FontSize', 10);
            end
        end       
        
% ----------------------------------------------------------------------
        % 6. DIAGRAMA DE OJO (Entrada al Receptor con Upsampling Artificial)
        % ----------------------------------------------------------------------
        if cfg.debug_eye
            figure('Name', '6. Diagrama de ojo', 'Color', 'w', 'Position', [250, 300, 600, 450]);
            
            span_eye = 2; % Mostrar 2 tiempos de símbolo
            N_symbs_plot = 1000; % Ventana de régimen permanente
            
            % Tomamos la señal de entrada al receptor (salida del canal cruda)
            N_samps_ch = min(N_symbs_plot * OVS_CH, length(ch));
            y_raw = ch(end - N_samps_ch + 1 : end);
            
            % Upsampling artificial utilizando resample para lograr trazas fluidas
            factor_interp = 8;
            y_raw_up = resample(y_raw, factor_interp, 1);
            
            OVS_PLOT = OVS_CH * factor_interp;
            Ns_ch_up = span_eye * OVS_PLOT;
            
            Neye_raw = floor(length(y_raw_up)/Ns_ch_up) * Ns_ch_up;
            
            if Neye_raw > 0
                eye_raw = reshape(real(y_raw_up(1:Neye_raw)), Ns_ch_up, []);
                t_raw = ((0:Ns_ch_up-1) / OVS_PLOT).'; 
                
                % Trazos en color morado para identificar la señal sin ecualizar
                plot(t_raw, eye_raw, 'Color', [0.4940 0.1840 0.5560 0.25], 'LineWidth', 0.5);
            end
            
            grid on; 
            xlim([0 span_eye]);
            
            % Autocalibración del eje Y para evitar picos espurios del resample
            ylim_val = max(abs(eye_raw(:))) * 1.1;
            if ~isempty(ylim_val) && ylim_val > 0
                ylim([-ylim_val ylim_val]);
            end
            
            xlabel('Tiempo [T_s]', 'FontWeight', 'bold');
            ylabel('Amplitud (Rama I)', 'FontWeight', 'bold');
            title('Diagrama de Ojo - Entrada al Receptor (Canal)');
        end
    end % Fin if cfg.en_debug_rx
