function [ber_sim, errors_sim] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec)
    
    Nm = length(M_vec);
    Ne = length(EbNo_BER);
    
    %Matrices para alojar valores de BER y errores
    ber_sim = zeros(Nm, Ne);
    errors_sim = zeros(Nm, Ne);
    
    % Orden de modulacion
    for m_idx = 1:Nm
        M_actual = M_vec(m_idx);
        cfg_s.M = M_actual; % Actualiza el orden en la configuración
        
        
        % Barrida de EbNo
        for idx = 1:Ne

            cfg_s.EbNo   = EbNo_BER(idx);
            cfg_s.Lsymbs = L_vec(idx);
            
            % Transmisor
            o_tx_s = transmisor_QAM(cfg_s);
            ak = o_tx_s.ak;
            i_canal = o_tx_s.o_tx;
            
            % Canal
            o_canal = channel(i_canal, cfg_s);
            
            % Receptor
            o_rx = Receiver(o_canal, cfg_s,ak);
            
            % Ber checker (Almacenamiento matricial)
            [ber, errors] = BER_checker(o_rx.ak_hat, ak, cfg_s.M, 0);
            ber_sim(m_idx, idx)    = ber;
            errors_sim(m_idx, idx) = errors;
            
            % Mostrar progreso por consola
            fprintf('M = %2d | Eb/No = %2d dB | BER = %e | Errores = %d\n', ...
                    M_actual, cfg_s.EbNo, ber, errors);
        end
    end
    
    % --- GRÁFICO COMPARATIVO DE LAS CURVAS ---
    figure('Name', 'Comparativa de Rendimiento M-QAM', 'Position', [200, 200, 800, 600]);
    
    % Paleta de colores para diferenciar las modulaciones (I: Teórica, II: Simulada)
    colores = ["#0072BD", "#D95319", "#EDB120", "#7E2F8E"]; 
    leyendas = cell(1, 2 * Nm); % Preasigna espacio para las etiquetas de la leyenda
    
    for m_idx = 1:Nm
        M_actual = M_vec(m_idx);
        color_actual = colores(mod(m_idx-1, length(colores)) + 1);
        
        % 1. Calcular y graficar la curva teórica correspondiente
        ber_teorica = berawgn(EbNo_BER, 'qam', M_actual);
        h_teorica = semilogy(EbNo_BER, ber_teorica, '-', 'Color', color_actual, 'LineWidth', 2); 
        hold on;
        
        % 2. Graficar los puntos simulados obtenidos de la matriz
        h_simulada = semilogy(EbNo_BER, ber_sim(m_idx, :), 'o--', 'Color', color_actual, ...
                              'MarkerFaceColor', color_actual, 'MarkerSize', 6);
        
        % Guardar etiquetas dinámicas para la leyenda
        leyendas{2*m_idx - 1} = sprintf('Teórica %d-QAM', M_actual);
        leyendas{2*m_idx}     = sprintf('Simulada %d-QAM', M_actual);
    end
    
    grid on;
    xlabel('E_b/N_0 (dB)');
    ylabel('BER');
    title('BER vs E_b/N_0');
    legend(leyendas, 'Location', 'best');
    ylim([1e-10 1]); % Ajustado a 1e-6, límite estadístico confiable para 1e6 símbolos
    hold off;
end