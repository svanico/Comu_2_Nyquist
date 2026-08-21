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
        % Tomamos una ventana corta (ej. 50 símbolos) para poder apreciar la forma de onda
        N_symbs_plot = 50; 
        N_samps_plot = N_symbs_plot * OVS_CH;
        
        % Ejes X: Esto alinea gráficamente los símbolos discretos con la señal sobremuestreada
        eje_sym = 1:N_symbs_plot;
        eje_samp = (1:N_samps_plot) / OVS_CH; % Eje en "Tiempos de Símbolo"
        
        % --- Subplot A: Símbolos Generados (Parte Real / In-Phase) ---
        subplot(2,2,1);
        stem(eje_sym, real(tx.ak(1:N_symbs_plot)), 'filled', 'Color', '#0072BD', 'LineWidth', 1.5);
        grid on; box on;
        xlabel('Índice de Símbolo (n)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Símbolos Tx (Re\{ak\})');
        
        % --- Subplot B: Símbolos Generados (Parte Imaginaria / Quadrature) ---
        subplot(2,2,3);
        stem(eje_sym, imag(tx.ak(1:N_symbs_plot)), 'filled', 'Color', '#D95319', 'LineWidth', 1.5);
        grid on; box on;
        xlabel('Índice de Símbolo (n)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Símbolos Tx (Im\{ak\})');
        
        % --- Subplot C: Salida del Filtro Transmisor ---
        subplot(2,2,2);
        plot(eje_samp, real(tx.o_tx(1:N_samps_plot)), 'Color', '#0072BD', 'LineWidth', 1.5);
        grid on; box on;
        xlabel('Tiempo (Normalizado a Ts)', 'FontWeight', 'bold');
        ylabel('Amplitud', 'FontWeight', 'bold');
        title('Señal Transmitida (Filtro Tx - Parte Real)');
        
        % --- Subplot D: Señal en la entrada del Receptor ---
        subplot(2,2,4);
        plot(eje_samp, real(ch(1:N_samps_plot)), 'Color', '#7E2F8E', 'LineWidth', 1);        grid on; box on;
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
            
            % PSD de las señales
            [Ptx, f_ch_psd] = pwelch(tx.o_tx, win, overlap, NFFT, fs_ch, 'centered');
            [Pch, ~]        = pwelch(ch, win, overlap, NFFT, fs_ch, 'centered');
            [Prx, ~]        = pwelch(rx.y, win, overlap, NFFT, fs_ch, 'centered');
            
            % Respuesta en frecuencia del Ecualizador
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
            xlabel('Frecuencia [GHz]', 'FontWeight', 'bold');
            ylabel('Magnitud / PSD normalizada [dB]', 'FontWeight', 'bold');
            title(sprintf('PSD (M=%d, Eb/No=%.1fdB)', cfg.M, cfg.EbNo));
            legend('Location','best');
        end
        
        % ----------------------------------------------------------------------
        % 2. MÉTRICAS DEL AGC
        % ----------------------------------------------------------------------
        figure('Name', '4. Acción del AGC', 'Color', 'w', 'Position', [150, 150, 1000, 500]);
        
        N_plot = min(2000, length(rx.agc_in)); 
        eje_n = 1:N_plot;
        
        subplot(2,2,1);
        plot(eje_n, abs(rx.agc_in(1:N_plot)), 'Color', '#7E2F8E');
        grid on; box on;
        ylabel('Magnitud Absoluta', 'FontWeight', 'bold');
        title('Señal de entrada (Directa del Canal)');
        
        subplot(2,2,3);
        plot(eje_n, abs(rx.agc_out(1:N_plot)), 'Color', '#0072BD');
        grid on; box on;
        xlabel('Muestras', 'FontWeight', 'bold');
        ylabel('Magnitud Absoluta', 'FontWeight', 'bold');
        media_salida = mean(abs(rx.agc_out));
        title(sprintf('Señal de salida AGC (Media: %.3f)', media_salida));
        
        subplot(2,2,[2, 4]);
        hold on;
        histogram(abs(rx.agc_in), 50, 'Normalization', 'pdf', 'FaceColor', '#7E2F8E', 'FaceAlpha', 0.6, 'DisplayName', 'Entrada');
        histogram(abs(rx.agc_out), 50, 'Normalization', 'pdf', 'FaceColor', '#0072BD', 'FaceAlpha', 0.6, 'DisplayName', 'Salida (Target AGC)');
        grid on; box on; hold off;
        legend('Location', 'northeast');
        xlabel('Magnitud Absoluta', 'FontWeight', 'bold');
        ylabel('Densidad de Probabilidad', 'FontWeight', 'bold');
        title('Distribución de Amplitudes (Varianza Normalizada)');

        % ----------------------------------------------------------------------
        % 3. ECUALIZADOR (Convergencia, SNR, evolución taps, rta temporal y frecuencial)
        % ----------------------------------------------------------------------
        figure('Name', '3. Dinámica del Ecualizador FFE', 'Color', 'w', 'Position', [100, 100, 1600, 700]);
        
        subplot(2,4,1);
        N_filt = 100;
        mse_smooth = 10*log10(filter(ones(N_filt,1)./N_filt, 1, abs(rx.error_base_log).^2));
        plot(mse_smooth, 'LineWidth', 2, 'Color', '#0072BD');
        grid on; box on;
        xline(cfg.t4_ffe_dd / FRAME_LOG, 'r--', 'Switch a DD', 'LabelVerticalAlignment', 'bottom');
        xlabel('Iteraciones (x10)', 'FontWeight', 'bold'); 
        ylabel('MSE [dB]', 'FontWeight', 'bold');
        title(sprintf('Evolución del MSE (Final: %.2f dB)', rx.MSE));
        
        subplot(2,4,2);
        P_signal = mean(abs(tx.ak).^2);
        snr_est = 10*log10(P_signal ./ filter(ones(N_filt,1)./N_filt, 1, abs(rx.error_base_log).^2));
        plot(snr_est, 'LineWidth', 2, 'Color', '#EDB120');
        grid on; box on;
        xline(cfg.t4_ffe_dd / FRAME_LOG, 'r--', 'Switch a DD', 'LabelVerticalAlignment', 'bottom');
        xlabel('Iteraciones (x10)', 'FontWeight', 'bold'); 
        ylabel('SNR Estimada [dB]', 'FontWeight', 'bold');
        title(sprintf('Relación Señal-Ruido (Final: %.2f dB)', snr_est(end)));
        
        subplot(2,4,3);
        htaps_finales = rx.htaps; 
        eje_taps = 1:cfg.NTAPS_ffe;
        stem(eje_taps, abs(htaps_finales), 'filled', 'LineWidth', 1.5, ...
             'MarkerSize', 6, 'Color', '#7E2F8E', 'MarkerFaceColor', '#7E2F8E');
        grid on; box on;
        idx_central = floor(cfg.NTAPS_ffe/2) + 1;
        hold on;
        plot(idx_central, abs(htaps_finales(idx_central)), 'ro', 'MarkerSize', 10, 'LineWidth', 1.5);
        hold off;
        xlabel('Índice del Tap', 'FontWeight', 'bold');
        ylabel('Magnitud |h(n)|', 'FontWeight', 'bold');
        title('Forma Temporal (Taps Finales)');
        max_tap_val = max(abs(htaps_finales));
        text(2, max_tap_val*0.9, sprintf('Total Taps: %d\nCentro: %d', cfg.NTAPS_ffe, idx_central), ...
             'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 9);
             
        subplot(2,4,4);
        N_fft = 1024;
        H_ffe_resp = fft(htaps_finales, N_fft);
        H_ffe_resp = H_ffe_resp(1:N_fft/2); 
        f_norm = linspace(0, 0.5, N_fft/2); 
        plot(f_norm, 20*log10(abs(H_ffe_resp) + eps), 'LineWidth', 2, 'Color', '#D95319');
        grid on; box on;
        xlabel('Frecuencia normalizada (f/f_s)', 'FontWeight', 'bold');
        ylabel('Magnitud [dB]', 'FontWeight', 'bold');
        title('Respuesta en frecuencia');
        
        taps_to_plot = rx.htaps_log(:, 1:20:end);
        iter_axis = (1:size(taps_to_plot, 2)) * FRAME_LOG * 20;
        taps_matrix = taps_to_plot.'; 
        
        subplot(2,4,5);
        plot(iter_axis, real(taps_matrix), 'LineWidth', 1);
        grid on; box on;
        xline(cfg.t4_ffe_dd, 'r--', 'Switch a DD');
        xlabel('Iteraciones', 'FontWeight', 'bold');
        ylabel('Re{h(n)}', 'FontWeight', 'bold');
        title('Evolución de todos los Taps (Real)');
        
        subplot(2,4,6);
        plot(iter_axis, imag(taps_matrix), 'LineWidth', 1);
        grid on; box on;
        xline(cfg.t4_ffe_dd, 'r--', 'Switch a DD');
        xlabel('Iteraciones', 'FontWeight', 'bold');
        ylabel('Im{h(n)}', 'FontWeight', 'bold');
        title('Evolución de todos los Taps (Imaginaria)');
        
        subplot(2,4,[7 8]);
        axis off;
        resumen_str = {
            '\bf--- Resumen del FFE ---', ...
            sprintf('  • Total Taps: %d', cfg.NTAPS_ffe), ...
            sprintf('  • MSE Final: %.2f dB', rx.MSE), ...
            sprintf('  • SNR Final: %.2f dB', snr_est(end))
        };
        text(0.3, 0.5, resumen_str, 'FontSize', 12, ...
             'BackgroundColor', [0.96 0.96 0.96], 'EdgeColor', [0.6 0.6 0.6], 'Margin', 10);

% ----------------------------------------------------------------------
        % 4. RECUPERACIÓN DE PORTADORA (PLL Y CONSTELACIONES)
        % ----------------------------------------------------------------------
        if cfg.en_carrier_recovery
            % Agrandamos el ancho de la figura para que entren 3 columnas (1400 px)
            figure('Name', '4. Recuperación de Portadora (PLL)', 'Color', 'w', 'Position', [150, 250, 1400, 750]);
            
            symb_axis = (1:length(rx.phase_integral_log)) .* FRAME_LOG;
            
            % --- Subplot 1: Trayectoria de Fase (NCO) ---
            subplot(2,3,1);
            
            % Envolvemos la fase para que no se escape a infinito
            fase_envuelta = wrapToPi(rx.phase_acc_log);
            
            plot(symb_axis, fase_envuelta, 'LineWidth', 1.5, 'Color', '#77AC30');
            grid on; hold on;
            xline(cfg.t2_fcr_v4, 'r--', 'FCR ON', 'LabelVerticalAlignment', 'bottom');
            
            % Agregamos límites fijos en el eje Y para ver mejor los saltos
            ylim([-pi, pi]);
            yticks([-pi, -pi/2, 0, pi/2, pi]);
            yticklabels({'-\pi', '-\pi/2', '0', '\pi/2', '\pi'});
            
            xlabel('Símbolos', 'FontWeight', 'bold'); 
            ylabel('Ángulo de Corrección [rad]', 'FontWeight', 'bold');
            title('Trayectoria de Fase (NCO)');
            
            % --- Subplot 2: Seguimiento de Frecuencia ---
            subplot(2,3,2);
            freq_est_MHz = rx.phase_integral_log .* cfg.BR ./ (2*pi) ./ 1e6;
            plot(symb_axis, freq_est_MHz, 'LineWidth', 2, 'Color', '#A2142F');
            grid on; hold on;
            if isfield(cfg, 'delta_freq')
                yline(cfg.delta_freq / 1e6, 'k--', 'Offset Real', 'LineWidth', 1.5);
            end
            xline(cfg.t2_fcr_v4, 'r--', 'FCR ON', 'LabelVerticalAlignment', 'bottom');
            xlabel('Símbolos', 'FontWeight', 'bold'); 
            ylabel('Offset Estimado [MHz]', 'FontWeight', 'bold');
            title('Seguimiento de Frecuencia');

% --- Subplot 3: Respuesta en Frecuencia del PLL (Bode FCR) ---
            subplot(2,3,3);
            if isfield(cfg, 'Kp') && isfield(cfg, 'Ki')
                % 1. Extracción de variables
                Kp = cfg.Kp; 
                Ki = cfg.Ki; 
                BR = cfg.BR;
              
                % 2. Generación del vector de frecuencias (Resolución logarítmica)
                n_freq_pos = 2^16;
                n_freq_frac = 2^16;
                n_v = [0, logspace(-log10(n_freq_frac), log10(n_freq_pos), n_freq_pos+n_freq_frac-1)];
                
                f_v = n_v * BR / 2 / n_freq_pos;
                wd_v = n_v * pi / n_freq_pos;
                
                % 3. Función de Transferencia Analítica sin Latencia
                % G(w) = (Kp + Ki/(1-z^-1)) * 1/(1-z^-1)
                G_th_v = (Kp + Ki .* 1./(1 - exp(-1j.*wd_v))) .* 1./(1 - exp(-1j.*wd_v));
                % H(w) = G(w) / (1 + G(w))
                H_th_v = G_th_v ./ (1 + G_th_v);
                
                H_th_db_v = 20*log10(abs(H_th_v));
                
                % 4. Ploteo principal
                p = semilogx(f_v, H_th_db_v, '-', 'Linewidth', 1.5, 'Color', '#0072BD');
                hold on;
                
                % Marcas de referencia (-3 dB)
                plot(xlim, [-3 -3], '-.m', 'Linewidth', 1, 'DisplayName', '-3 dB');
                
                % 5. Estética y Leyendas
                grid on; 
                xlim([1e6, 1e9]);
                
                xlabel('Frecuencia [Hz]', 'FontWeight', 'bold');
                ylabel('Amplitud [dB]', 'FontWeight', 'bold');
                
                % Título ajustado (paréntesis cerrado)
                title(sprintf('Jitter Transfer (BR=%.2f GBd)', BR/1e9));
                
                % Leyenda dinámica (sin el string vacío)
                leg_str = sprintf('Kp = %.2e\nKi = %.2e', Kp, Ki);
                legend(leg_str, '-3 dB', 'Location', 'southwest', 'FontSize', 8);
                
            else
                % Fallback amigable
                text(0.5, 0.5, 'Variables Kp y/o Ki no encontradas en cfg', ...
                     'HorizontalAlignment', 'center', 'Color', 'r');
                axis off;
                title('FCR Jitter Transfer Function');
            end
            
            % --- Preparación para Constelaciones ---
            N_tail = min(2000, length(rx.slicer_in_log));
            slicer_in = rx.slicer_in_log;
            phase_acc = rx.phase_acc_log;
            ffe_out = slicer_in .* exp(1j * phase_acc);
            
            % --- Subplot 4: Constelación ANTES del FCR ---
            subplot(2,3,4);
            scatter(real(ffe_out(end-N_tail:end)), imag(ffe_out(end-N_tail:end)), 10, 'filled', 'MarkerFaceColor', '#7E2F8E', 'MarkerFaceAlpha', 0.6);
            grid on; axis square;
            xlabel('In-Phase (I)', 'FontWeight', 'bold');
            ylabel('Quadrature (Q)', 'FontWeight', 'bold');
            title('ANTES del FCR (Salida FFE)');
            
            % --- Subplot 5: Constelación DESPUÉS del FCR ---
            subplot(2,3,5);
            scatter(real(slicer_in(end-N_tail:end)), imag(slicer_in(end-N_tail:end)), 10, 'filled', 'MarkerFaceColor', '#D95319', 'MarkerFaceAlpha', 0.6);
            grid on; axis square;
            xlabel('In-Phase (I)', 'FontWeight', 'bold');
            ylabel('Quadrature (Q)', 'FontWeight', 'bold');
            title('DESPUÉS del FCR (Entrada Slicer)');
            
            % Nota: El Subplot 6 (2,3,6) queda intencionalmente vacío, 
            % lo cual da un respiro visual muy lindo a la figura.
        end       
        % ----------------------------------------------------------------------
        % 6. EVOLUCIÓN TEMPORAL
        % ----------------------------------------------------------------------
        figure('Name', 'Entrada al Slicer', 'Color', 'w');
        
        subplot(2,1,1);
        plot(real(rx.slicer_in_log), '.');
        grid on;
        xlabel('Símbolos');
        ylabel('Parte Real');
        title('Entrada al Slicer - Rama I');
        
        subplot(2,1,2);
        plot(imag(rx.slicer_in_log), '.');
        grid on;
        xlabel('Símbolos');
        ylabel('Parte Imaginaria');
        title('Entrada al Slicer - Rama Q');

    %% 7. DIAGRAMAS DE OJO (Antes y Después del DSP)
    if cfg.debug_eye
        figure('Name', '6. Diagramas de ojo', 'Color', 'w', 'Position', [150, 300, 1000, 450]);
        
        span_eye = 2; % Mostrar 2 tiempos de símbolo
        N_symbs_plot = 1000; % Ventana de régimen permanente
        
        % ==================================================================
        % OJO 1: Entrada al Receptor (Señal del canal cruda)
        % ==================================================================
        subplot(1,2,1);
        
        % Extraemos muestras del final, dependiendo del oversampling del canal
        N_samps_ch = min(N_symbs_plot * OVS_CH, length(ch)); 
        y_raw = ch(end - N_samps_ch + 1 : end);
        
        % Normalizamos la amplitud para que se compare visualmente bien con la salida
        
        Ns_ch = span_eye * OVS_CH;
        Neye_raw = floor(length(y_raw)/Ns_ch) * Ns_ch;
        
        if Neye_raw > 0
            eye_raw = reshape(real(y_raw(1:Neye_raw)), Ns_ch, []);
            t_raw = ((0:Ns_ch-1) / OVS_CH).'; 
            
            plot(t_raw, eye_raw, 'Color', [0.4940 0.1840 0.5560 0.25], 'LineWidth', 0.5);
        end
        grid on; xlim([0 span_eye]);
        xlabel('Tiempo [T_s]', 'FontWeight', 'bold');
        ylabel('Amplitud (Rama I)', 'FontWeight', 'bold');
        title('ANTES (Entrada RX - Canal)');
        
        % ==================================================================
        % OJO 2: Entrada al Slicer (Ecualizada y Derotada)
        % ==================================================================
        subplot(1,2,2);
        
        N_samps_dsp = min(N_symbs_plot * OVS_DSP, length(rx.ffe_out_log));
        y_eq = rx.ffe_out_log(end - N_samps_dsp + 1 : end);
        
        % Tomamos la fase del final de la simulación
        %steady_phase = rx.phase_acc_log(end);
        
        % Derotamos la señal
        %y_eq_derot = y_eq .* exp(-1j * steady_phase);
        
        Ns_dsp = span_eye * OVS_DSP;
        Neye_eq = floor(length(y_eq)/Ns_dsp) * Ns_dsp;
        
        if Neye_eq > 0
            eye_eq = reshape(real(y_eq(1:Neye_eq)), Ns_dsp, []);
            t_eq = ((0:Ns_dsp-1) / OVS_DSP).'; 
            
            % Ploteo en azul con transparencia
            plot(t_eq, eye_eq, 'Color', [0 0.4470 0.7410 0.25], 'LineWidth', 0.5);
        end
        grid on; xlim([0 span_eye]);
        xlabel('Tiempo [T_s]', 'FontWeight', 'bold');
        ylabel('Amplitud (Rama I)', 'FontWeight', 'bold');
        title('DESPUÉS (Entrada Slicer)');
    end
        
    end % Fin if cfg.en_debug_rx
end