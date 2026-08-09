function debug_dashboard(cfg, tx, ch, rx)
    if ~cfg.en_debug_plots && ~cfg.en_plots_rx
        return; % Si todo el debugging está apagado, salimos.
    end

    fprintf('\n--- Abriendo Dashboard de Depuración ---\n');
    
    % Variables de entorno
    OVS_CH  = cfg.OVS.CH;
    OVS_DSP = cfg.OVS.DSP;
    fs_ch  = OVS_CH * cfg.BR;
    fs_dsp = OVS_DSP * cfg.BR;
    FRAME_LOG = 10; % Tasa de decimación de los logs
    
   %% 1. DENSIDAD ESPECTRAL DE POTENCIA (PSD) Y ECUALIZADOR

    if cfg.debug_psd
        NFFT = 4096;
        win_len = min(2048, length(tx.o_tx));
        win = hamming(win_len);
        overlap = floor(win_len/2);
        
        % 1. PSD de las señales (calculadas a la frecuencia del canal, fs_ch)
        [Ptx, f_ch] = pwelch(tx.o_tx, win, overlap, NFFT, fs_ch, 'centered');
        [Pch, ~]    = pwelch(ch, win, overlap, NFFT, fs_ch, 'centered');
        [Prx, ~]    = pwelch(rx.y, win, overlap, NFFT, fs_ch, 'centered');
        
        % 2. Respuesta en frecuencia del Ecualizador (Taps finales)
        % Calculada a la frecuencia del DSP (fs_dsp)
        H_ffe = fftshift(fft(rx.htaps, NFFT));
        f_dsp = linspace(-fs_dsp/2, fs_dsp/2, NFFT); % Eje X propio del FFE
        
        figure('Name','1. Dominio de Frecuencia (PSD)', 'Color', 'w', 'Position', [100, 100, 800, 500]);
        
        % Ploteo de las señales
        plot(f_ch/1e9, 10*log10(Ptx./max(Ptx) + eps), 'LineWidth', 1.3, 'DisplayName', 'Salida TX');
        hold on;
        plot(f_ch/1e9, 10*log10(Pch./max(Pch) + eps), 'LineWidth', 1.3, 'DisplayName', 'Salida Canal');
        plot(f_ch/1e9, 10*log10(Prx./max(Prx) + eps), 'LineWidth', 1.3, 'DisplayName', 'Filtro Anti-Alias RX');
        
        % Ploteo del Ecualizador (línea negra punteada gruesa)
        % Normalizamos a su valor máximo para que la forma sea comparable a las PSD
        plot(f_dsp/1e9, 20*log10(abs(H_ffe)./max(abs(H_ffe)) + eps), ...
             'k--', 'LineWidth', 2.5, 'DisplayName', 'Respuesta FFE (Normalizada)');
        
        grid on; box on;
        xlabel('Frecuencia [GHz]', 'FontWeight', 'bold');
        ylabel('Magnitud / PSD normalizada [dB]', 'FontWeight', 'bold');
        title(sprintf('Densidad Espectral y Ecualización (M=%d, Eb/No=%.1fdB)', cfg.M, cfg.EbNo));
        legend('Location','best');
    end

    %% 2. MÉTRICAS DEL AGC
    figure('Name','2. Control Automático de Ganancia', 'Color', 'w', 'Position', [150, 150, 800, 500]);
    % Calculamos la potencia móvil (envolvente) de entrada y salida
    win_pwr = 1000; % Ventana móvil
    pwr_in = filter(ones(win_pwr,1)/win_pwr, 1, abs(rx.agc_in).^2);
    pwr_out = filter(ones(win_pwr,1)/win_pwr, 1, abs(rx.agc_out).^2);
    
    plot(pwr_in(win_pwr:end), 'LineWidth', 1.5, 'DisplayName', 'Potencia Entrada (Canal)');
    hold on;
    plot(pwr_out(win_pwr:end), 'LineWidth', 1.5, 'DisplayName', 'Potencia Salida (Normalizada)');
    grid on; box on;
    xlabel('Muestras', 'FontWeight', 'bold');
    ylabel('Potencia Promedio Móvil', 'FontWeight', 'bold');
    title('Métricas del AGC: Estabilización de Amplitud');
    legend('Location', 'best');

%% 3. ECUALIZADOR (Convergencia, SNR, Evolución y Respuesta Temporal)
    figure('Name', '3. Dinámica del Ecualizador FFE', 'Color', 'w', 'Position', [100, 100, 1400, 700]);
    
    % --- Subplot A: MSE ---
    subplot(2,3,1);
    N_filt = 100;
    mse_smooth = 10*log10(filter(ones(N_filt,1)./N_filt, 1, abs(rx.error_base_log).^2));
    plot(mse_smooth, 'LineWidth', 2, 'Color', '#0072BD');
    grid on; box on;
    xline(cfg.t4_ffe_dd / FRAME_LOG, 'r--', 'Switch a DD', 'LabelVerticalAlignment', 'bottom');
    xlabel('Iteraciones (x10)', 'FontWeight', 'bold'); 
    ylabel('MSE [dB]', 'FontWeight', 'bold');
    title(sprintf('Evolución del MSE (Final: %.2f dB)', rx.MSE));
    
    % --- Subplot B: SNR Estimada ---
    subplot(2,3,2);
    P_signal = mean(abs(tx.ak).^2);
    snr_est = 10*log10(P_signal ./ filter(ones(N_filt,1)./N_filt, 1, abs(rx.error_base_log).^2));
    plot(snr_est, 'LineWidth', 2, 'Color', '#EDB120');
    grid on; box on;
    xline(cfg.t4_ffe_dd / FRAME_LOG, 'r--', 'Switch a DD', 'LabelVerticalAlignment', 'bottom');
    xlabel('Iteraciones (x10)', 'FontWeight', 'bold'); 
    ylabel('SNR Estimada [dB]', 'FontWeight', 'bold');
    title(sprintf('Relación Señal-Ruido (Final: %.2f dB)', snr_est(end)));
    
    % --- Subplot C: Respuesta al Impulso del FFE (Forma Temporal) ---
    subplot(2,3,3);
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

    % --- Preparación de datos para la evolución de los Taps ---
    downsample_factor = 20; 
    taps_to_plot = rx.htaps_log(:, 1:downsample_factor:end);
    iter_axis = (1:size(taps_to_plot, 2)) * FRAME_LOG * downsample_factor;
    energia_final_taps = abs(taps_to_plot(:, end));
    [~, indices_ordenados] = sort(energia_final_taps, 'descend');
    
    num_taps_to_show = min(51, cfg.NTAPS_ffe); % Evita error si NTAPS_ffe < 51
    taps_principales = indices_ordenados(1:num_taps_to_show);
    colores = lines(num_taps_to_show);
    taps_secundarios = setdiff(1:cfg.NTAPS_ffe, taps_principales);

    % --- Subplot D: Evolución de Taps - PARTE REAL ---
    subplot(2,3,4);
    hold on;
    for i = 1:num_taps_to_show
        idx_tap = taps_principales(i);
        plot(iter_axis, real(taps_to_plot(idx_tap, :)), 'LineWidth', 1.2, ...
             'Color', colores(i,:), 'DisplayName', sprintf('Tap %d', idx_tap));
    end
    
    if ~isempty(taps_secundarios)
        ruido_promedio_real = mean(real(taps_to_plot(taps_secundarios, :)), 1);
        plot(iter_axis, ruido_promedio_real, 'k--', 'LineWidth', 1, ...
             'DisplayName', 'Ruido (Promedio)');
    end
    
    grid on; box on;
    xline(cfg.t4_ffe_dd, 'r--', 'DD');
    xlabel('Iteraciones', 'FontWeight', 'bold');
    ylabel('Re{h(n)}', 'FontWeight', 'bold');
    title('Evolución de Taps (Parte Real)');
    hold off;

    % --- Subplot E: Evolución de Taps - PARTE IMAGINARIA ---
    subplot(2,3,5);
    hold on;
    for i = 1:num_taps_to_show
        idx_tap = taps_principales(i);
        plot(iter_axis, imag(taps_to_plot(idx_tap, :)), 'LineWidth', 1.2, ...
             'Color', colores(i,:), 'DisplayName', sprintf('Tap %d', idx_tap));
    end
    
    if ~isempty(taps_secundarios)
        ruido_promedio_imag = mean(imag(taps_to_plot(taps_secundarios, :)), 1);
        plot(iter_axis, ruido_promedio_imag, 'k--', 'LineWidth', 1, ...
             'DisplayName', 'Ruido (Promedio)');
    end
    
    grid on; box on;
    xline(cfg.t4_ffe_dd, 'r--', 'DD');
    xlabel('Iteraciones', 'FontWeight', 'bold');
    ylabel('Im{h(n)}', 'FontWeight', 'bold');
    title('Evolución de Taps (Parte Imaginaria)');
    hold off;

    % --- Subplot F: Cuadro de Resumen FFE ---
    subplot(2,3,6);
    axis off;
    resumen_str = {
        '\bf--- Resumen del FFE ---', ...
        sprintf('  • Total Taps: %d', cfg.NTAPS_ffe), ...
        sprintf('  • Taps Principales: %d', num_taps_to_show), ...
        sprintf('  • Downsample Factor: %d', downsample_factor), ...
        sprintf('  • MSE Final: %.2f dB', rx.MSE), ...
        sprintf('  • SNR Final: %.2f dB', snr_est(end))
    };
    text(0.1, 0.5, resumen_str, 'FontSize', 11, ...
         'BackgroundColor', [0.96 0.96 0.96], 'EdgeColor', [0.6 0.6 0.6], 'Margin', 10);

%% 4. RECUPERACIÓN DE PORTADORA (PLL Y CONSTELACIONES)
    if cfg.en_carrier_recovery
        figure('Name', '4. Recuperación de Portadora (PLL)', 'Color', 'w', 'Position', [250, 250, 1000, 750]);
        
        symb_axis = (1:length(rx.phase_integral_log)) .* FRAME_LOG;
        
        % Subplot A: Corrección de Fase (NCO / Phase Accumulator)
        subplot(2,2,1);
        % phase_acc_log almacena la fase en radianes, pero no está acotada entre -pi y pi,
        % así que crecerá indefinidamente si hay un offset de frecuencia constante.
        plot(symb_axis, rx.phase_acc_log, 'LineWidth', 1.5, 'Color', '#77AC30');
        
        grid on; hold on;
        xline(cfg.t2_fcr_v4, 'r--', 'FCR ON', 'LabelVerticalAlignment', 'bottom');
        
        xlabel('Símbolos', 'FontWeight', 'bold'); 
        ylabel('Ángulo de Corrección [rad]', 'FontWeight', 'bold');
        title('Trayectoria de Fase (NCO)');

        % Subplot B: Rama Integral / Seguimiento de Frecuencia (Temporal)
        subplot(2,2,2);
        freq_est_MHz = rx.phase_integral_log .* cfg.BR ./ (2*pi) ./ 1e6;
        plot(symb_axis, freq_est_MHz, 'LineWidth', 2, 'Color', '#A2142F');
        grid on; hold on;
        yline(cfg.delta_freq / 1e6, 'k--', 'Offset Real', 'LineWidth', 1.5);
        xline(cfg.t2_fcr_v4, 'r--', 'FCR ON', 'LabelVerticalAlignment', 'bottom');
        xlabel('Símbolos', 'FontWeight', 'bold'); 
        ylabel('Offset Estimado [MHz]', 'FontWeight', 'bold');
        title('Seguimiento de Frecuencia (Rama Integral)');
        
        % Extraer los últimos 2000 símbolos para las constelaciones
        %N_tail = min(2000, length(rx.slicer_in_log));
        slicer_in_final = rx.slicer_in_log;
        phase_acc_final = rx.phase_acc_log;
        
        % Reconstruir matemáticamente la salida del FFE (antes de derotar)
        % Como: slicer_in = ffe_out * exp(-1j * phase_acc)
        % Entonces: ffe_out = slicer_in * exp(+1j * phase_acc)
        ffe_out_raw = slicer_in_final .* exp(1j * phase_acc_final);

        % Subplot C: Constelación ANTES del FCR (Salida directa del ecualizador)
        subplot(2,2,3);
        scatter(real(ffe_out_raw), imag(ffe_out_raw), 10, 'filled', 'MarkerFaceColor', '#7E2F8E', 'MarkerFaceAlpha', 0.6);
        grid on; axis square;
        xlabel('In-Phase (I)', 'FontWeight', 'bold');
        ylabel('Quadrature (Q)', 'FontWeight', 'bold');
        title('ANTES del FCR (Salida del Ecualizador)');

        % Subplot D: Constelación DESPUÉS del FCR (Entrada al Slicer)
        subplot(2,2,4);
        scatter(real(slicer_in_final), imag(slicer_in_final), 10, 'filled', 'MarkerFaceColor', '#D95319', 'MarkerFaceAlpha', 0.6);
        grid on; axis square;
        xlabel('In-Phase (I)', 'FontWeight', 'bold');
        ylabel('Quadrature (Q)', 'FontWeight', 'bold');
        title('DESPUÉS del FCR (Entrada al Slicer)');
    end    %% 5. DIAGRAMA DE OJO Y CONSTELACIÓN (Salida del Slicer)
    figure('Name', '5. Calidad de Señal al Slicer', 'Color', 'w', 'Position', [300, 300, 1000, 500]);
    
    % Constelación en régimen estacionario (últimos 2000 símbolos)
    subplot(1,2,1);
    N_tail = min(2000, length(rx.slicer_in_log));
    scatter(real(rx.slicer_in_log(end-N_tail:end)), imag(rx.slicer_in_log(end-N_tail:end)), 15, 'filled', 'MarkerFaceAlpha', 0.6);
    grid on; axis square;
    xlabel('In-Phase (I)', 'FontWeight', 'bold');
    ylabel('Quadrature (Q)', 'FontWeight', 'bold');
    title('Constelación Ecualizada');

    % Diagrama de Ojo
    if cfg.debug_eye
        subplot(1,2,2);
        span_eye = 2; 
        Ns_eye = span_eye * OVS_DSP;
        
        % Extraemos la señal estacionaria del FFE log
        N_steady_samps = min(1000 * OVS_DSP, length(rx.ffe_out_log));
        y_eye = rx.ffe_out_log(end-N_steady_samps:end);
        
        % Normalizamos el ojo a la fase del PLL para que no se vea rotado
        steady_phase = rx.phase_acc_log(end);
        y_eye = y_eye .* exp(-1j * steady_phase);
        
        Neye = floor(length(y_eye)/Ns_eye) * Ns_eye;
        eye_I = reshape(real(y_eye(1:Neye)), Ns_eye, []);
        
        t_eye = (0:Ns_eye-1) / (cfg.BR * OVS_DSP) / (1/cfg.BR); 
        
        plot(t_eye, eye_I, 'b', 'LineWidth', 0.4);
        grid on; xlim([0 span_eye]);
        xlabel('Tiempo normalizado [T_s]', 'FontWeight', 'bold');
        ylabel('Amplitud (Rama I)', 'FontWeight', 'bold');
        title('Diagrama de Ojo (Últimos símbolos)');
        
    end
    %% Evolución temporal a la entrada del slicer
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
end