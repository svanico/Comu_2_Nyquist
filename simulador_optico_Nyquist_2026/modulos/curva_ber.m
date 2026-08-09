function [ber_sim, errors_sim] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec)
    
    Nm = length(M_vec);
    Ne = length(EbNo_BER);


    % Casos de canal
    ch_bw_vec = [0 17.75e9 15.75e9 15e9];
    ch_names  = {'Impulso', 'Leve', 'Moderada', 'Agresiva'};
    
    Nch = length(ch_bw_vec);


    
    %Matrices para alojar valores de BER y errores
    ber_sim = zeros(Nch, Nm, Ne);
    errors_sim = zeros(Nch, Nm, Ne);
    
    % % % Orden de modulacion
    % % for m_idx = 1:Nm
    % %     M_actual = M_vec(m_idx);
    % %     cfg_s.M = M_actual; % Actualiza el orden en la configuración
    % % 
    % % 
    % %     % Barrida de EbNo
    % %     for idx = 1:Ne
    % % 
    % %         cfg_s.EbNo   = EbNo_BER(idx);
    % %         cfg_s.Lsymbs = L_vec(idx);
    % % 
    % %         % cfg_s.t1_rfd    = fix(0.10 * cfg_s.Lsymbs); % Pasa a Etapa 2 (Prende RFD)
    % %         % cfg_s.t2_fcr_v4 = fix(0.20 * cfg_s.Lsymbs); % Pasa a Etapa 3 (Prende Fase Ciega)
    % %         % cfg_s.t3_fcr_dd = fix(0.35 * cfg_s.Lsymbs); % Pasa a Etapa 4 (FCR a DD, apaga RFD)
    % %         % cfg_s.t4_ffe_dd = fix(0.45 * cfg_s.Lsymbs); % Pasa a Etapa 5 (FFE a DD LMS);
    % %         % 
    % % 
    % %         cfg_s.t1_rfd = fix(cfg_s.t1_rfd_frac * cfg_s.Lsymbs);
    % %         cfg_s.t2_fcr_v4 = fix(cfg_s.t2_fcr_v4_frac * cfg_s.Lsymbs);
    % %         cfg_s.t3_fcr_dd = fix(cfg_s.t3_fcr_dd_frac * cfg_s.Lsymbs);
    % %         cfg_s.t4_ffe_dd = fix(cfg_s.t4_ffe_dd_frac * cfg_s.Lsymbs);
    % % 
    % % 
    % %         % Transmisor
    % %         o_tx_s = transmisor_QAM(cfg_s);
    % %         ak = o_tx_s.ak;
    % %         i_canal = o_tx_s.o_tx;
    % % 
    % %         % Canal
    % %         o_canal = channel(i_canal, cfg_s);
    % % 
    % %         % Receptor
    % %         o_rx = Receiver(o_canal, cfg_s,ak);
    % % 
    % %         % Ber checker (Almacenamiento matricial)
    % % 
    % %         % N      = length(o_rx);
    % %         guard  = 0;%fix(0.5*N);
    % % 
    % % 
    % %         [ber, errors] = BER_checker(o_rx.ak_hat_fixed, o_rx.ak_tx_aligned, cfg_s.M,guard);
    % % 
    % %         ber_sim(m_idx, idx)    = ber;
    % %         errors_sim(m_idx, idx) = errors;
    % % 
    % %         % Mostrar progreso por consola
    % %         % fprintf('M = %2d | Eb/No = %2d dB | BER = %e | Errores = %d\n', ...
    % %         %         M_actual, cfg_s.EbNo, ber, errors);
    % % 
    % % 
    % % 
    % %         fprintf(['M = %2d | Eb/No = %2d dB | BER = %e | ' ...
    % %      'Errores = %d | MSE = %.2f dB | CS = %d\n'], ...
    % %     M_actual, cfg_s.EbNo, ber, errors, ...
    % %     o_rx.MSE, o_rx.cs_count);
    % %     end
    % % end

    % Barrida de los distintos canales
        for ch_idx = 1:Nch
        
            % Configuración del canal
            if ch_idx == 1
                % Canal impulso
                cfg_s.en_ch_filter = 0;
            else
                % Canal distorsivo
                cfg_s.en_ch_filter = 1;
                cfg_s.ch_bw = ch_bw_vec(ch_idx);
            end
        
            % fprintf('\n========== CANAL: %s ==========\n', ch_names{ch_idx});
        
            % Orden de modulacion
            for m_idx = 1:Nm
        
                M_actual = M_vec(m_idx);
                cfg_s.M = M_actual;
        
                % Barrida de EbNo
                for idx = 1:Ne
        
                    cfg_s.EbNo   = EbNo_BER(idx);
                    cfg_s.Lsymbs = L_vec(idx);
        
                    % Timers del receptor
                    cfg_s.t1_rfd     = fix(cfg_s.t1_rfd_frac     * cfg_s.Lsymbs);
                    cfg_s.t2_fcr_v4  = fix(cfg_s.t2_fcr_v4_frac  * cfg_s.Lsymbs);
                    cfg_s.t3_fcr_dd  = fix(cfg_s.t3_fcr_dd_frac  * cfg_s.Lsymbs);
                    cfg_s.t4_ffe_dd  = fix(cfg_s.t4_ffe_dd_frac  * cfg_s.Lsymbs);
        
                    % Transmisor
                    o_tx_s = transmisor_QAM(cfg_s);
                    ak = o_tx_s.ak;
                    i_canal = o_tx_s.o_tx;
        
                    % Canal
                    o_canal = channel(i_canal, cfg_s);
        
                    % Receptor
                    o_rx = Receiver(o_canal, cfg_s, ak);
        
                    % BER checker
                    guard = 0;
        
                    [ber, errors] = BER_checker( ...
                        o_rx.ak_hat_fixed, ...
                        o_rx.ak_tx_aligned, ...
                        cfg_s.M, ...
                        guard);
        
                    % Guardamos: canal x modulacion x EbNo
                    ber_sim(ch_idx, m_idx, idx) = ber;
                    errors_sim(ch_idx, m_idx, idx) = errors;
        
                    % fprintf(['Canal = %-9s | M = %2d | Eb/No = %.1f dB | ' ...
                    %          'BER = %e | Errores = %d | MSE = %.2f dB | CS = %d\n'], ...
                    %          ch_names{ch_idx}, M_actual, cfg_s.EbNo, ...
                    %          ber, errors, o_rx.MSE, o_rx.cs_count);
        
                end
            end
        end


    % % 
    % % % --- GRÁFICO COMPARATIVO DE LAS CURVAS ---
    % % figure('Name', 'Comparativa de Rendimiento M-QAM', 'Position', [200, 200, 800, 600]);
    % % 
    % % % Paleta de colores para diferenciar las modulaciones (I: Teórica, II: Simulada)
    % % colores = ["#0072BD", "#D95319", "#EDB120", "#7E2F8E"]; 
    % % leyendas = cell(1, 2 * Nm); % Preasigna espacio para las etiquetas de la leyenda
    % % 
    % % for m_idx = 1:Nm
    % %     M_actual = M_vec(m_idx);
    % %     color_actual = colores(mod(m_idx-1, length(colores)) + 1);
    % % 
    % %     % 1. Calcular y graficar la curva teórica correspondiente
    % %     ber_teorica = berawgn(EbNo_BER, 'qam', M_actual);
    % %     h_teorica = semilogy(EbNo_BER, ber_teorica, '-', 'Color', color_actual, 'LineWidth', 2); 
    % %     hold on;
    % % 
    % %     % 2. Graficar los puntos simulados obtenidos de la matriz
    % %     h_simulada = semilogy(EbNo_BER, ber_sim(m_idx, :), 'o--', 'Color', color_actual, ...
    % %                           'MarkerFaceColor', color_actual, 'MarkerSize', 6);
    % % 
    % %     % Guardar etiquetas dinámicas para la leyenda
    % %     leyendas{2*m_idx - 1} = sprintf('Teórica %d-QAM', M_actual);
    % %     leyendas{2*m_idx}     = sprintf('Simulada %d-QAM', M_actual);
    % % end
    % % 
    % % grid on;
    % % xlabel('E_b/N_0 (dB)');
    % % ylabel('BER');
    % % title('BER vs E_b/N_0');
    % % legend(leyendas, 'Location', 'best');
    % % ylim([1e-10 1]); % Ajustado a 1e-6, límite estadístico confiable para 1e6 símbolos
    % % hold off;

    % --- GRÁFICO COMPARATIVO DE LOS CANALES ---

    colores = ["#0072BD", "#D95319", "#EDB120", "#7E2F8E"];
    
    for m_idx = 1:Nm
    
        M_actual = M_vec(m_idx);
    
        figure('Name', sprintf('BER %d-QAM - Distorsión de canal', M_actual), ...
               'Position', [200, 200, 800, 600]);
    
        hold on;
    
        % Curva teórica
        ber_teorica = berawgn(EbNo_BER, 'qam', M_actual);
    
        semilogy(EbNo_BER, ber_teorica, 'k-', ...
                 'LineWidth', 2, ...
                 'DisplayName', sprintf('Teórica %d-QAM', M_actual));
    
        % Curvas simuladas para cada canal
        for ch_idx = 1:Nch
    
            ber_actual = squeeze(ber_sim(ch_idx, m_idx, :));
    
            semilogy(EbNo_BER, ber_actual, 'o--', ...
                     'Color', colores(ch_idx), ...
                     'MarkerFaceColor', colores(ch_idx), ...
                     'MarkerSize', 6, ...
                     'DisplayName', ch_names{ch_idx});
        end
    
        grid on;
        xlabel('E_b/N_0 (dB)');
        ylabel('BER');
        title(sprintf('BER vs E_b/N_0 - %d-QAM', M_actual));
    
        legend('Location', 'best');
        
        set(gca, 'YScale', 'log');
        ylim([1e-5 1]);
    
        hold off;
    end


end