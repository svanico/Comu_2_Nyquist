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
    
    agc_target = .3;                             %esto es a ojo (creemos)
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
    if M == 16
        const_pts = qammod(0:M-1, M); 
        radii = unique(round(abs(const_pts)*1e4)/1e4); % [1.414, 3.162, 4.242]
        th_low = (radii(1) + radii(2))/2;
        th_high = (radii(2) + radii(3))/2;
    elseif M == 4
        th_low = inf; th_high = -inf; % En QPSK todos los símbolos sirven
    else
        th_low = 0; th_high = 0; % Deshabilita RFD para otras modulaciones
    end

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
                    last_angle = angle_curr; last_detection = 1;
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
                end
                
            elseif idx_new < t4_ffe_dd
                % FFE-CMA + FCR-DD
                phase_error = imag(slicer_in * conj(slicer_out))/(abs(slicer_in) * abs(slicer_out));
                
            else
                % FFE-DD + FCR-DD
                phase_error = imag(slicer_in * conj(slicer_out))/(abs(slicer_in) * abs(slicer_out));
            end

            % PLL
            phase_integral = phase_integral + Ki * phase_error + rfd_gain_value;
            loop_filter_out = (Kp * phase_error) + phase_integral;
            phase_acc = phase_acc + loop_filter_out;
            
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
    s_in_cs.WINDOW_LEN = 500; 
    s_in_cs.M = M;
    
    s_out_cs = dinamic_CS_corrector(s_in_cs);
    
    ak_tx_aligned_trunc = ak_aligned(1 : length(s_out_cs.orx_cs_fixed));

%% Variables para el main
    % 1. Salidas principales
    o_data_rx.ak_hat_raw = ak_hat_arr;                
    o_data_rx.ak_hat_fixed = s_out_cs.orx_cs_fixed; 
    o_data_rx.ak_tx_aligned = ak_tx_aligned_trunc;   
    o_data_rx.o_dws  = o_dws_arr;
    
    % 2. Cálculo del Error Cuadrático Medio (MSE) final
    ventana_evaluacion = min(10000, length(error_log) - 1); 
    MSE = 10 * log10(mean(abs(error_log(end - ventana_evaluacion : end)).^2));
    o_data_rx.MSE = MSE;
    
    % 3. Variables de debug
    o_data_rx.error_log = error_log;
    o_data_rx.slicer_in_log = slicer_in_log;
    o_data_rx.phase_acc_log = phase_acc_log;
    o_data_rx.htaps = htaps;
    o_data_rx.ffe_out_log = ffe_out_log;
    o_data_rx.ovs_ffe = ovs_ffe; 
end