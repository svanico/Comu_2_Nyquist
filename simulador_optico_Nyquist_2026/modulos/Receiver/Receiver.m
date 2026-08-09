function [o_data_rx] = Receiver(i_rx, i_cfg_s, ak)
%Settings
    M = i_cfg_s.M;
    Lsymbs = i_cfg_s.Lsymbs;
    BR = i_cfg_s.BR;
    NTAPS = i_cfg_s.NTAPS_RRC;
    NTAPS_ffe = i_cfg_s.NTAPS_ffe;
    
    ovs_ch = i_cfg_s.OVS.CH;
    ovs_ffe = i_cfg_s.OVS.DSP;

    rolloff = i_cfg_s.rolloff;
    t0 = 0;
    
    agc_target = 1;                             %esto es a ojo (creemos)
    % R_CMA   =   cfg_s.R_CMA;
    % R_CMA = sqrt(mean(abs(ak(1:1000)).^4)/mean(abs(ak(1:1000)).^2));
    R_CMA = (mean(abs(ak(1:1000)).^4)/mean(abs(ak(1:1000)).^2));

    dd_step = i_cfg_s.dd_step;
    cma_step = i_cfg_s.cma_step;
    leak = i_cfg_s.leak;

    %RFD y PLL, timers
    rfd_gain = i_cfg_s.rfd_gain;
    last_angle = 0;
    last_detection = 0;

    t1_rfd    = i_cfg_s.t1_rfd;
    t2_fcr_v4 = i_cfg_s.t2_fcr_v4;
    t3_fcr_dd = i_cfg_s.t3_fcr_dd;
    t4_ffe_dd = i_cfg_s.t4_ffe_dd;
    
    % Anillos para identificar símbolos QPSK
    % (Para 16-QAM, separa el anillo interno y las esquinas externas)
    % if M == 16
    %     const_pts = qammod(0:M-1, M); 
    %     radii = unique(round(abs(const_pts)*1e4)/1e4); % [1.414, 3.162, 4.242]
    %     th_low = (radii(1) + radii(2))/2;
    %     th_high = (radii(2) + radii(3))/2;
    % elseif M == 4
    %     th_low = inf; th_high = -inf; % En QPSK todos los símbolos sirven
    % else
    %     th_low = 0; th_high = 0; % Deshabilita RFD para otras modulaciones
    % end


    th_low = (sqrt(2) + sqrt(10) )/2;
    th_high = (sqrt(10) + sqrt(18) )/2;


    Ki = i_cfg_s.Ki;
    Kp = i_cfg_s.Kp;

    FRAME_LOG_1x = 10;                          %guarda una muestra cada 10 símbolos.
    FRAME_LOG_2x = 10;

%% Anti Alias Filter
    [~,h_taps_ps] = root_raised_cosine(BR, BR*ovs_ch, rolloff, NTAPS, t0); %las salidas estaban al revés
    
    %Compensación del retardo de grupo
    delay_aaf = floor((NTAPS-1)/2);
    aaf_out_raw = filter(h_taps_ps, 1, [i_rx(:); zeros(NTAPS-1, 1)]);
    aaf_out = aaf_out_raw(delay_aaf+1 : end-delay_aaf);
    o_data_rx.y = aaf_out;

%% ADC (interpolador)
    tin=(0:length(aaf_out)-1)./(BR*ovs_ch);     %al vector de lo filtrado le sacamos el ovr_ch
    tout=(0:1/(BR*ovs_ffe):tin(end)) ;          %creo un vector con ovr_fse
    dsp_in = interp1(tin,aaf_out,tout,'linear','extrap');   %interpolo el vector de lo filtrado con el nuevo vec anterior q esta a tasa ovr_fse

%% Digital AGC
    agc_out = dsp_in ./ std(dsp_in) * agc_target; %a lo interpolado lo divido por la varianza y lo multiplico por un factor

%% EQ y FCR
    %Inicializacion de matrices y variables
    htaps = zeros(NTAPS_ffe,1);
    htaps(floor(NTAPS_ffe/2)-1) = 1;            %Impulso
    buffer_filter = zeros(NTAPS_ffe,1);         %BUFFER para la señal recibida
    phase_integral = 0;
    phase_acc = 0; % Equivale al nco_output

    %%Variables to logging
    ffe_out_log = zeros(ceil(Lsymbs*ovs_ffe/FRAME_LOG_2x),1);
    error_log = zeros(ceil(Lsymbs/FRAME_LOG_1x),1);
    slicer_in_log = zeros(ceil(Lsymbs/FRAME_LOG_1x),1);
    phase_acc_log = zeros(ceil(Lsymbs/FRAME_LOG_1x), 1);
    phase_integral_log = zeros(ceil(Lsymbs/FRAME_LOG_1x), 1);
    phase_error_log = zeros(ceil(Lsymbs/FRAME_LOG_1x), 1);

    N_symbs_rx = ceil(length(agc_out) / ovs_ffe); %cantidad de simbolos recibidos
    ak_hat_arr = zeros(N_symbs_rx, 1);
    o_dws_arr  = zeros(N_symbs_rx, 1);

    for idx=1:length(agc_out) %a tasa de sobremuestreo
        buffer_filter(2:end) = buffer_filter(1:end-1); 
        buffer_filter(1) = agc_out(idx);               
                                                %antes: [x1 x2 x3 x4] ; después
                                                %del shift: [x1 x1 x2 x3] ;
                                                %después de meter muestra nueva: [x_new x1 x2 x3]
        ffe_out = htaps.'*buffer_filter;        %filtra
        
       if mod(idx,ovs_ffe)==0                  % calculo el resto, si da 0, continuo (downsampling)  
            idx_new = ceil(idx/ovs_ffe);        % Convierte el índice de muestra idx en índice de símbolo
            
            slicer_in_raw = ffe_out;
            slicer_in = slicer_in_raw * exp(-1j * phase_acc); % Derotación
            slicer_out = slicer(slicer_in, M);
            
            y_mod = abs(slicer_in);
            is_qpsk_like = (M==4) || (y_mod < th_low || y_mod > th_high);
            
            % Inicializamos variables de error por defecto
            phase_error = 0;
            rfd_gain_value = 0;

            % Etapas 1 a 5
            if idx_new < t1_rfd
                % FFE-CMA
                
            elseif idx_new < t2_fcr_v4
                % FFE-CMA + RFD
                if is_qpsk_like
                    angle_curr = mod(angle(slicer_in), pi/2) - pi/4;
                    if last_detection
                         diff_angle = angle_curr - last_angle;
                         if abs(diff_angle) > pi/4 
                             rfd_gain_value = -sign(diff_angle) * rfd_gain;
                         end
                    end
                    last_angle = angle_curr; 
                    last_detection = 1;
                else
                    last_detection = 0;
                end
                
            elseif idx_new < t3_fcr_dd
                % FFE-CMA + RFD + FCR(4th Power)
                if is_qpsk_like
                    phase_error = mod(angle(slicer_in), pi/2) - pi/4; % FCR V4
                    
                    angle_curr = mod(angle(slicer_in), pi/2) - pi/4;  % RFD
                    if last_detection
                         diff_angle = angle_curr - last_angle;
                         if abs(diff_angle) > pi/4 
                             rfd_gain_value = -sign(diff_angle) * rfd_gain;
                         end
                    end
                    last_angle = angle_curr; last_detection = 1;
                else
                    last_detection = 0;
                    rfd_gain_value = 0;
                end
                
            elseif idx_new < t4_ffe_dd
                % FFE-CMA + FCR-DD
                phase_error = imag(slicer_in * conj(slicer_out))/(abs(slicer_in) * abs(slicer_out));
                
            else
                % FFE-DD + FCR-DD
                phase_error = imag(slicer_in * conj(slicer_out))/(abs(slicer_in) * abs(slicer_out));
            end

            % PLL
            % phase_integral = phase_integral + Ki * phase_error + rfd_gain_value;
            % loop_filter_out = (Kp * phase_error) + phase_integral;
            % phase_acc = phase_acc + loop_filter_out;

            % PLL
            if i_cfg_s.en_carrier_recovery
            
                phase_integral = phase_integral ...
                               + Ki * phase_error ...
                               + rfd_gain_value;
            
                loop_filter_out = Kp * phase_error + phase_integral;
                phase_acc = phase_acc + loop_filter_out;
            
            else
            
                % Sin errores de portadora: no corregimos fase ni frecuencia
                phase_integral = 0;
                loop_filter_out = 0;
                phase_acc = 0;
            
            end

            % ECUALIZADOR
            if idx_new < t4_ffe_dd
                % Etapas 1, 2, 3 y 4 usan CMA
                error_base = slicer_in_raw*(abs(slicer_in_raw).^2 - R_CMA);
                error = error_base; 
                step = cma_step;
            else
                % Etapa 5 usa LMS (DD)
                error_base = slicer_in - slicer_out; 
                error = error_base * exp(1j * phase_acc); 
                step = dd_step;
            end

            ak_hat_arr(idx_new) = slicer_out;
            o_dws_arr(idx_new)  = slicer_in;
        
            htaps = (1-leak)*htaps - step*error*conj(buffer_filter);    
            
            % 8. LOGGING A TASA 1x (Decimado)
            if mod(idx_new,FRAME_LOG_1x)==0     
                idx_log = idx_new/FRAME_LOG_1x;         
                error_log(idx_log) = error;         
                slicer_in_log(idx_log) = slicer_in; 
                phase_acc_log(idx_log) = phase_acc; 
                phase_integral_log(idx_log) = phase_integral;
                phase_error_log(idx_log) = phase_error;
            end

        end
        
        % Logging a tasa fraccionaria
        if mod(idx,FRAME_LOG_2x)==0     
            ffe_out_log(idx/FRAME_LOG_2x) = ffe_out;    
        end
        
    end

    %% Align y CSC
    alig_delay = finddelay(ak, o_dws_arr);
    if alig_delay < 0
        alig_delay = 0;
    end
 
    guard = fix(0.8 * length(ak_hat_arr)); 
    
    % 3. Recortamos y alineamos vectores 
    ak_aligned = ak(1 + guard : end - alig_delay);
    o_dws_aligned = o_dws_arr(1 + guard + alig_delay : end);
    
    % 4. Armamos la estructura s_in que pide tu función
    s_in_cs = struct();
    s_in_cs.data_receive = o_dws_aligned;
    s_in_cs.stx = ak_aligned;
    s_in_cs.WINDOW_LEN = 50; 
    s_in_cs.M = M;
    
    [s_out_cs] = dinamic_CS_corrector(s_in_cs);
    
    ak_tx_aligned_trunc = ak_aligned(1 : length(s_out_cs.orx_cs_fixed));

    %% Chequeo alternativo: corrección global de cuadrante

% Usamos exactamente la misma cantidad de símbolos que el CS dinámico
N_global = min(length(o_dws_aligned), ...
               length(ak_tx_aligned_trunc));

rx_global_in = o_dws_aligned(1:N_global);
tx_global    = ak_tx_aligned_trunc(1:N_global);

rx_global_in = rx_global_in(:);
tx_global    = tx_global(:);

% Posibles ambigüedades de cuadrante de una constelación QAM
rot_candidates = exp(1j*(0:3)*pi/2);

mse_quadrant = zeros(4,1);

for q = 1:4
    rx_test = rx_global_in .* rot_candidates(q);

    mse_quadrant(q) = mean(abs(rx_test - tx_global).^2);
end

% Elegimos el cuadrante que mejor coincide con la referencia
[~, q_best] = min(mse_quadrant);

rx_global_fixed = rx_global_in .* rot_candidates(q_best);

% BER
Bref_global = qamdemod(tx_global, M, 'OutputType', 'bit');
Bhat_global = qamdemod(rx_global_fixed, M, 'OutputType', 'bit');

BER_global = mean(Bhat_global(:) ~= Bref_global(:));

% SER
Sref_global = qamdemod(tx_global, M);
Shat_global = qamdemod(rx_global_fixed, M);

SER_global = mean(Shat_global(:) ~= Sref_global(:));
% 
% fprintf(' BER con CS global      = %.4e   (SER = %.4e)\n', ...
%         BER_global, SER_global);
% 
% fprintf(' Cuadrante global elegido = %d grados\n', ...
%         (q_best-1)*90);


    %% ---------------- CHEQUEO DE BER DEL RECEPTOR ----------------

% Salida del slicer alineada con los símbolos transmitidos
ak_hat_aligned = ak_hat_arr(1 + guard + alig_delay : end);

% Nos aseguramos de comparar vectores de igual longitud
N_eval = min(length(ak_aligned), length(ak_hat_aligned));

ak_ref_eval = ak_aligned(1:N_eval);
ak_hat_eval = ak_hat_aligned(1:N_eval);

% Bits transmitidos y detectados antes del corrector de cycle slip
% Demodulación a bits para calcular BER
Bref_bits = qamdemod(ak_ref_eval, M, 'OutputType', 'bit');
Bhat_rx_bits = qamdemod(ak_hat_eval, M, 'OutputType', 'bit');

BER_rx = sum(Bhat_rx_bits(:) ~= Bref_bits(:)) / numel(Bref_bits);

% Demodulación a índices de símbolo para calcular SER
Bref_sym = qamdemod(ak_ref_eval, M);
Bhat_rx_sym = qamdemod(ak_hat_eval, M);

SER_rx = mean(Bhat_rx_sym(:) ~= Bref_sym(:));


% Bits después del corrector de cycle slip
N_eval_cs = min(length(ak_tx_aligned_trunc), ...
                length(s_out_cs.orx_cs_fixed));

% Forzamos ambas señales a vectores columna
ak_ref_cs = ak_tx_aligned_trunc(1:N_eval_cs);
ak_ref_cs = ak_ref_cs(:);

ak_hat_cs = s_out_cs.orx_cs_fixed(1:N_eval_cs);
ak_hat_cs = ak_hat_cs(:);

% Demodulación a bits para calcular BER
Bref_cs_bits = qamdemod(ak_ref_cs, M, 'OutputType', 'bit');
Bhat_cs_bits = qamdemod(ak_hat_cs, M, 'OutputType', 'bit');

BER_rx_cs = sum(Bhat_cs_bits(:) ~= Bref_cs_bits(:)) / ...
            numel(Bref_cs_bits);

% Demodulación a índices de símbolo para calcular SER
Bref_cs_sym = qamdemod(ak_ref_cs, M);
Bhat_cs_sym = qamdemod(ak_hat_cs, M);

SER_rx_cs = mean(Bhat_cs_sym(:) ~= Bref_cs_sym(:));

% % %% FINAL PRINTS
% % fprintf('--------------------------------------------\n');
% % fprintf(' BER salida del receptor = %.4e   (SER = %.4e)\n', ...
% %         BER_rx, SER_rx);
% % 
% % fprintf(' BER receptor + CS fix   = %.4e   (SER = %.4e)\n', ...
% %         BER_rx_cs, SER_rx_cs);
% % 
% % fprintf(' Simbolos evaluados      = %d\n', N_eval);
% % fprintf(' Simbolos evaluados CS   = %d\n', N_eval_cs);
% % fprintf('--------------------------------------------\n');
% % 



%% Variables para el main
    % 1. Salidas principales
    o_data_rx.ak_hat_raw = ak_hat_arr;                
    o_data_rx.ak_hat_fixed = s_out_cs.orx_cs_fixed; 
    o_data_rx.ak_tx_aligned = ak_tx_aligned_trunc;   
    o_data_rx.o_dws  = o_dws_arr;
    
    % % 2. Cálculo del Error Cuadrático Medio (MSE) final
    % ventana_evaluacion = min(10000, length(error_log) - 1); 
    % MSE = 10 * log10(mean(abs(error_log(end - ventana_evaluacion : end)).^2));
    % o_data_rx.MSE = MSE;

    % MSE normalizado entre la salida corregida y los símbolos transmitidos
    rx_mse = s_out_cs.orx_cs_fixed(:);
    tx_mse = ak_tx_aligned_trunc(:);
    
    N_mse = min(length(rx_mse), length(tx_mse));
    
    rx_mse = rx_mse(1:N_mse);
    tx_mse = tx_mse(1:N_mse);
    
    mse_norm = mean(abs(rx_mse - tx_mse).^2) / ...
               mean(abs(tx_mse).^2);
    
    o_data_rx.MSE = 10*log10(max(mse_norm, eps));
    
    % 3. Variables de debug
    o_data_rx.error_log = error_log;
    o_data_rx.slicer_in_log = slicer_in_log;
    o_data_rx.phase_acc_log = phase_acc_log;
    o_data_rx.phase_integral_log = phase_integral_log;
    o_data_rx.htaps = htaps;
    o_data_rx.ffe_out_log = ffe_out_log;
    o_data_rx.ovs_ffe = ovs_ffe; 
    o_data_rx.phase_error_log = phase_error_log;


    o_data_rx.cs_count = s_out_cs.cs_count;
    o_data_rx.cs_phase = s_out_cs.cs_phase;
    %% Gráfico de la rama integral del PLL
if i_cfg_s.en_plots_rx

    N_log_pll = floor(N_symbs_rx / FRAME_LOG_1x);

    phase_integral_plot = phase_integral_log(1:N_log_pll);

    % La rama integral representa incremento de fase por símbolo.
    % Multiplicando por BR/(2*pi) se convierte a frecuencia.
    freq_est_MHz = phase_integral_plot .* BR ./ (2*pi) ./ 1e6;

    symb_axis = (1:N_log_pll) .* FRAME_LOG_1x;

    figure;
    plot(symb_axis, freq_est_MHz, 'LineWidth', 2);
    grid on;
    hold on;

    xline(t1_rfd, '--', 'RFD ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    xline(t2_fcr_v4, '--', 'FCR V4 ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    xline(t3_fcr_dd, '--', 'FCR DD ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    xline(t4_ffe_dd, '--', 'FFE DD ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    hold off;

    xlabel('Símbolos', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Rama integral [MHz]', ...
           'Interpreter', 'latex', 'FontSize', 12);

    title('Estimación del offset de frecuencia', ...
          'Interpreter', 'latex', 'FontSize', 12);

    %% Gráfico del error de fase del PLL
    
    phase_error_plot = phase_error_log(1:N_log_pll);
    
    figure;
    plot(symb_axis, phase_error_plot, 'LineWidth', 1);
    grid on;
    hold on;
    
    yline(0, '-');
    
    xline(t1_rfd, '--', 'RFD ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    xline(t2_fcr_v4, '--', 'FCR V4 ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    xline(t3_fcr_dd, '--', 'FCR DD ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    xline(t4_ffe_dd, '--', 'FFE DD ON', ...
          'LabelVerticalAlignment', 'bottom');
    
    hold off;
    
    xlabel('Símbolos', ...
           'Interpreter', 'latex', 'FontSize', 12);
    
    ylabel('Error de fase [rad]', ...
           'Interpreter', 'latex', 'FontSize', 12);
    
    title('Error de fase del PLL', ...
          'Interpreter', 'latex', 'FontSize', 12);

end

end