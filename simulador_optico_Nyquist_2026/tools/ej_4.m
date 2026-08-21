function ej_4(cfg)

    % 1. Configuración del barrido
    N_barridos = 7; % Cantidad de curvas a graficar 
    delta_freq_vec = linspace(-cfg.BR/12, cfg.BR/12, N_barridos);

    % 2. Preparar figura
    figure('Name', 'Ejercicio 4 - Seguimiento de Frecuencia (DPLL)', 'Color', 'w', 'Position', [150, 250, 900, 600]);
    hold on; grid on;
    colores = lines(N_barridos); % Paleta de colores para superponer curvas
    FRAME_LOG = 1; % Escala del eje X 

    % 3. Ejecución del bucle
    for i = 1:length(delta_freq_vec)
        fprintf('\n--- Barrido Ejercicio 4 [%d/%d]: Offset = %.2f MHz ---\n', ...
                i, N_barridos, delta_freq_vec(i)/1e6);

        % Copiar configuración base y sobreescribir el offset
        cfg_temp = cfg;
        cfg_temp.delta_freq = delta_freq_vec(i);

        % Ejecutar bloques
        o_tx_s  = transmisor_QAM(cfg_temp);
        o_canal = channel(o_tx_s.o_tx, cfg_temp);
        o_rx    = Receiver(o_canal, cfg_temp, o_tx_s.ak);

        % Extraer y escalar la rama integral a MHz
        % (Se asume que o_rx.phase_integral_log existe y guarda rad/simbolo)
        if isfield(o_rx, 'phase_integral_log')
            freq_est_MHz = o_rx.phase_integral_log .* cfg_temp.BR ./ (2*pi) ./ 1e6;
            symb_axis = (1:length(freq_est_MHz)) .* FRAME_LOG;

            % Graficar curva del transitorio
            plot(symb_axis, freq_est_MHz, 'LineWidth', 1.5, 'Color', colores(i,:), ...
                 'DisplayName', sprintf('Transitorio (%.2f MHz)', delta_freq_vec(i)/1e6));
             
            % Graficar línea teórica de referencia (estado estacionario esperado)
            yline(delta_freq_vec(i)/1e6, '--', 'Color', colores(i,:), 'LineWidth', 1.2, ...
                 'HandleVisibility', 'off');
        else
            warning('No se encontró la variable phase_integral_log en o_rx.');
        end
    end

    % 4. Estética final del gráfico
    if isfield(cfg, 't2_fcr_v4')
        xline(cfg.t2_fcr_v4, 'k:', 'FCR ON', 'LabelVerticalAlignment', 'bottom', ...
              'LineWidth', 1.5, 'HandleVisibility', 'off');
    end

    xlabel('Símbolos', 'FontWeight', 'bold', 'FontSize', 11);
    ylabel('Frecuencia compensada [MHz]', 'FontWeight', 'bold', 'FontSize', 11);
    title(sprintf('Convergencia del Offset de Portadora (Rango ±%.2f GHz)', (cfg.BR/12)/1e9), 'FontSize', 12);
    
    % Ajustar límites para visualización óptima
    xlim([0, length(freq_est_MHz)]);
    legend('Location', 'best', 'FontSize', 9);
    hold off;
end