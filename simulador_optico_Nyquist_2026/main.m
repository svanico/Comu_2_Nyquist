clear; clc; close all;
%% 1. Parámetros generales
cfg_s = struct();
cfg_s.BR              = 32e9;       % Baud rate 
BR                    = cfg_s.BR;   
cfg_s.M               = 4;          % Orden de modulacion
cfg_s.Lsymbs          = 1e6;        % Cantidad de simbolos
cfg_s.rolloff         = 0.6;        % Exceso de ancho de banda
cfg_s.EbNo            = 30;         % valor de ebno para los graficos temporales/debugging
% Sobremuestreo
% cfg_s.OVS           = 2;          % Sobremuestreo original
cfg_s.OVS.CH          = 4;          % Sobremuestreo del transmisor/canal
OVS_CH                = cfg_s.OVS.CH;
cfg_s.OVS.DSP         = 2;          % Sobremuestreo del DSP/LMS
% Filtros transmisor
cfg_s.NTAPS_RRC       = 101;  
%% 2. Canal y ruido
cfg_s.en_ch_filter    = 1;          % Habilita fir del canal
cfg_s.en_n            = 1;          % Habilita AWGN
cfg_s.pos_n           = 0;          % 1:ruido coloreado, 0:blanco (por como pusimos el canal, metés el ruido antes del filtro del canal. Entonces el ruido también pasa por el filtro y queda coloreado.)
cfg_s.NTAPS_FIR       = 101;

%% 3. Errores de portadora
cfg_s.en_c_error      = 1;          % Habilita errores de portadora 
% --- Errores Estáticos y Estocásticos ---
cfg_s.delta_freq      = 10e6;        % Offset del LO
cfg_s.phase_offset    = 30/180*pi;  % Error de fase
cfg_s.LW              = 0e3;       % Ancho de linea [Hz] -> Ruido de fase
% --- Fluctuaciones y Tonos Interfirientes ---
cfg_s.freq_fluct_amp  = 0e6;
cfg_s.freq_fluct_freq = 0e3;
cfg_s.phase_tone_amp  = 0/180*pi;
cfg_s.phase_tone_freq = 0e6;
%% 4. Receptor (ecualizador y recuperador)
cfg_s.NTAPS_ffe       = 51;
% --- Parámetros de Convergencia (CMA y DD-LMS) ---
cfg_s.time_cma        = 50e3;       % tiempo del cma
%cfg_s.time_cma       = cfg_s.Lsymbs + 1; % para probar solo el cma (sin fse)
% cfg_s.R_CMA         = 13.2;       % cte de comparacion del cma usamos la de 16
cfg_s.cma_step        = 1e-3;
cfg_s.dd_step         = 1e-4;
cfg_s.leak            = 0e-6;
% --- Configuración del PLL (Carrier Recovery) ---
cfg_s.Kp              = 10e-3;      % Ganancia proporcional 
cfg_s.Ki              = cfg_s.Kp/1000; % Ganancia integral
% --- Configuración del RFD ---
cfg_s.rfd_gain = 1e-3;


%% 5. CONFIGURACIÓN DE SIMULACIONES Y DEBUGGING
% --- Habilitación de Bloques de Evaluación ---
cfg_s.en_plots_rx     = 1;          % Análisis del receptor (MSE, FFE, Constelación)
cfg_s.en_plots        = 0;          % Habilitar graficos temporales (Tx/Rx)
cfg_s.en_curva_ber    = 0;          % Habilitar simulacion en cascada para la curva ber
% --- Herramientas de Debugging General ---
cfg_s.en_debug_plots  = 1;          % Habilita bloque entero de debugging
cfg_s.debug_psd       = 0;          % PSD
cfg_s.debug_eye       = 0;          % Diagrama de ojo
cfg_s.debug_const     = 1;          % Constelacion
cfg_s.debug_Nsymbs    = 1e6;        % Cantidad de simbolos para graficar
% --- Vectores para Curva BER ---
EbNo_BER              = 0:2:10;
M_vec                 = [4 16];
% L_vec = [1e4, 1e4, 1e4, 1e5, 1e6, 1e7, 1e6, 1e6, 1e6]; % vector de símbolos variable para cada EbNo
L_vec                 = [2e5 2e5 2e5 5e5 1e6 1e6 1e6 1e6 1e6]; % subi los Lvec pq el time_cma = 50e3, pero en L_vec para los primeros Eb/No usás 1e4, 1e4, 1e4, 1e5. Entonces para varias simulaciones el receptor está todo o casi todo en etapa CMA, y aun así lo estás contando en la BER.

%% EJECUCIÓN PRINCIPAL DEL SISTEMA
% Llamada a la función superior de simulación (BER en cascada)
if cfg_s.en_curva_ber
    [ber_simulada, errores_totales] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec);
end


% Config bloques individuales (Transmisión única)
% Transmisor
o_tx_s = struct();
o_tx_s = transmisor_QAM(cfg_s);
ak     = o_tx_s.ak;
ak_up  = o_tx_s.ak_ovs;
o_tx   = o_tx_s.o_tx;
rrc    = o_tx_s.rrc;
% Canal
i_canal = o_tx;
o_canal = channel(i_canal,cfg_s);
% Receptor
i_rx = o_canal;
o_rx = struct();
o_rx = Receiver(i_rx,cfg_s,ak); % con pasarle solo ak esta ok
y = o_rx.y;
yk = o_rx.o_dws;
ak_hat = o_rx.ak_hat;
% Ber checker
guard = cfg_s.time_cma + 1000;
[ber,errors]  = BER_checker(ak_hat,ak, cfg_s.M, guard);
o_data_rx.ber = ber;
o_data_rx.errors = errors;
%% DEBUGGING Y GRÁFICOS (Evaluación)
% Debugging general: PSD, diagrama de ojo y constelacion
if cfg_s.en_debug_plots
    % OVS = cfg_s.OVS;
    % fs  = cfg_s.OVS * cfg_s.BR;
    OVS_CH  = cfg_s.OVS.CH;
    OVS_DSP = cfg_s.OVS.DSP;
    
    fs_ch  = OVS_CH  * cfg_s.BR;
    fs_dsp = OVS_DSP * cfg_s.BR;
    Ndbg_symbs = min(cfg_s.debug_Nsymbs, length(yk));
    % Ndbg_samps = min(Ndbg_symbs * OVS, length(o_tx));
    Ndbg_samps = min(Ndbg_symbs * OVS_CH, length(o_tx));
    
    %%PSD
    if cfg_s.debug_psd
        NFFT = 4096;
        win_len = min(2048, length(o_tx));
        win = hamming(win_len);
        overlap = floor(win_len/2);
        % [Ptx, f] = pwelch(o_tx, win, overlap, NFFT, fs, 'centered');
        % [Pch, ~] = pwelch(o_canal, win, overlap, NFFT, fs, 'centered');
        % [Prx, ~] = pwelch(y, win, overlap, NFFT, fs, 'centered');
        [Ptx, f] = pwelch(o_tx, win, overlap, NFFT, fs_ch, 'centered');
        [Pch, ~] = pwelch(o_canal, win, overlap, NFFT, fs_ch, 'centered');
        [Prx, ~] = pwelch(y, win, overlap, NFFT, fs_ch, 'centered');
        figure('Name','Debugging - PSD');
        plot(f/1e9, 10*log10(Ptx./max(Ptx) + eps), 'LineWidth', 1.3);
        hold on;
        plot(f/1e9, 10*log10(Pch./max(Pch) + eps), 'LineWidth', 1.3);
        plot(f/1e9, 10*log10(Prx./max(Prx) + eps), 'LineWidth', 1.3);
        grid on;
        xlabel('Frecuencia [GHz]');
        ylabel('PSD normalizada [dB]');
        title(sprintf('PSD - M = %d, Eb/No = %d dB', cfg_s.M, cfg_s.EbNo));
        legend('Salida TX', 'Salida canal', 'Salida filtro RX', 'Location','best');
    end
    
    %%Diagrama de ojo
    if cfg_s.debug_eye
        span_eye = 2;                 % simbolos por traza
        % Ns_eye = span_eye * OVS;      % muestras por traza
        Ns_eye = span_eye * OVS_CH;
        Neye = floor(length(y)/Ns_eye) * Ns_eye;
        Neye = min(Neye, 300 * Ns_eye); % cantidad maxima de trazas
        y_eye = y(1:Neye);
        eye_I = reshape(real(y_eye), Ns_eye, []);    % real(y_eye)  => rama I y reshape me da una matriz donde cada columna es una traza del ojo
        eye_Q = reshape(imag(y_eye), Ns_eye, []);    % imag(y_eye)  => rama Q y reshape me da una matriz donde cada columna es una traza del ojo
        % t_eye = (0:Ns_eye-1) / fs;
        t_eye = (0:Ns_eye-1) / fs_ch;
        t_eye = t_eye / (1/cfg_s.BR); % tiempo normalizado a Ts
        figure('Name','Debugging - Diagrama de ojo');
        subplot(2,1,1);
        plot(t_eye, eye_I, 'LineWidth', 0.8);    % grafica todas las columnas superpuestas. Eso forma el diagrama de ojo
        grid on;
        xlabel('Tiempo normalizado [T_s]');
        ylabel('Amplitud');
        title('Diagrama de ojo - Rama I');
        subplot(2,1,2);
        plot(t_eye, eye_Q, 'LineWidth', 0.8);
        grid on;
        xlabel('Tiempo normalizado [T_s]');
        ylabel('Amplitud');
        title('Diagrama de ojo - Rama Q');
    end
    
    %%Constelacion
    if cfg_s.debug_const
        Nconst = min(cfg_s.debug_Nsymbs, length(yk));
        Nconst = min(Nconst, length(ak));
        figure('Name','Debugging - Constelacion');
        plot(real(ak(1:Nconst)), imag(ak(1:Nconst)), 'o', ...
            'DisplayName','Símbolos TX');
        hold on;
        plot(real(yk(1:Nconst)), imag(yk(1:Nconst)), '.', ...
            'DisplayName','Muestras RX antes del slicer');  % Grafica las muestras recibidas después del filtro y del downsampler, pero antes del slicer. las muestras yk(las nubes)
        plot(real(ak_hat(1:Nconst)), imag(ak_hat(1:Nconst)), 'x', ...
            'DisplayName','Símbolos decididos');   % Grafica los símbolos después del slicer.
        grid on;
        axis equal;
        xlabel('In-Phase');
        ylabel('Quadrature');
        title(sprintf('Constelacion - M = %d, Eb/No = %d dB', cfg_s.M, cfg_s.EbNo));
        legend('Location','best');
    end
end

% Debugging Receiver
if  cfg_s.en_plots_rx
    
    % Extraemos las variables del último receptor ejecutado
    error_log = o_rx.error_log;
    htaps = o_rx.htaps;
    slicer_in_log = o_rx.slicer_in_log;
    acc_log = o_rx.acc_log;
    ovs_ffe = o_rx.ovs_ffe;
    
    fprintf('\n--- Análisis de Convergencia del Ecualizador ---\n');
    fprintf('MSE Final LMS = %.2f dB\n', o_rx.MSE);

    figure('Name', 'Resumen del DSP (LMS + PLL)', 'Color', 'w', 'Position', [100, 100, 1100, 700]);
    
    % Título general de la ventana
    sgtitle('Análisis de Convergencia: FSE & Carrier Recovery', 'FontSize', 15, 'FontWeight', 'bold');

    % 1. Figura MSE 
    subplot(2, 3, [1, 2]);
    N_filt = 100;
    plot(10*log10(filter(ones(N_filt,1)./N_filt, 1, abs(error_log).^2)), 'LineWidth', 2)
    grid on; box on;
    xlabel('Iteración (x10)', 'FontWeight', 'bold'); 
    ylabel('Potencia de Error [dB]', 'FontWeight', 'bold');
    title('Evolución del MSE');

    % 2. Constelación de salida 
    subplot(2, 3, 3);
    plot(real(slicer_in_log(end-2000:end)), imag(slicer_in_log(end-2000:end)), '.', 'MarkerSize', 8, 'Color', '#D95319')
    grid on; box on; axis square;
    xlabel('In-Phase (I)', 'FontWeight', 'bold'); 
    ylabel('Quadrature (Q)', 'FontWeight', 'bold');
    title('Constelación a la entrada del slicer');

    % 3. Respuesta del FFE en el Tiempo (Posición 4)
    subplot(2, 3, 4);
    stem(abs(htaps), 'LineWidth', 1.5, 'MarkerFaceColor', '#0072BD');
    grid on; box on;
    xlabel('Índice del Tap', 'FontWeight', 'bold'); 
    ylabel('Magnitud', 'FontWeight', 'bold');
    title('FFE Time Impulse Response (Magnitude)');

    % 4. Respuesta del FFE en Frecuencia (Posición 5)
    subplot(2, 3, 5);
    NFFT = 4096;
    Fs = cfg_s.BR * ovs_ffe;
    H = fft(htaps, NFFT);
    f = linspace(0, Fs/2, NFFT/2);
    plot(f/1e9, 20*log10(abs(H(1:NFFT/2))+1e-12), 'LineWidth', 2, 'Color', '#EDB120')
    grid on; box on;
    xlabel('Frecuencia [GHz]', 'FontWeight', 'bold'); 
    ylabel('Magnitud [dB]', 'FontWeight', 'bold');
    title('FFE Frequency Response');

    % 5. Cuadro de texto con Leyendas y Parámetros (Posición 6)
    subplot(2, 3, 6);
    axis off; % Ocultamos los ejes para dejar solo el texto flotando
    
    param_str = {
        '\bf--- Parámetros de Simulación ---', ...
        sprintf('  • Eb/No: %d dB', cfg_s.EbNo), ...
        sprintf('  • Baud Rate: %g GBd', cfg_s.BR/1e9), ...
        sprintf('  • Símbolos: %g', cfg_s.Lsymbs), ...
        '', ...
        '\bf--- Errores de Portadora ---', ...
        sprintf('  • Offset Freq (\\Delta f): %g MHz', cfg_s.delta_freq/1e6), ...
        sprintf('  • Offset Fase (\\theta_0): %g^o', cfg_s.phase_offset * 180/pi), ...
        sprintf('  • Linewidth (LW): %g kHz', cfg_s.LW/1e3), ...
        '', ...
        '\bf--- Desempeño y DSP ---', ...
        sprintf('  • Taps del FFE: %d', cfg_s.NTAPS_ffe), ...
        sprintf('  • Kp PLL: %g', cfg_s.Kp), ...
        sprintf('  • Ki PLL: %g', cfg_s.Ki), ...
        sprintf('  • MSE Final: %.2f dB', o_rx.MSE)
    };
    
    text(0.05, 0.5, param_str, 'FontSize', 10, 'VerticalAlignment', 'middle', ...
         'BackgroundColor', [0.96 0.96 0.96], 'EdgeColor', [0.6 0.6 0.6], 'Margin', 8);
    
    % Reconstruimos la señal a tasa del DSP (2x) filtrada con los taps convergidos
    OVS_DSP = cfg_s.OVS.DSP;
    OVS_CH  = cfg_s.OVS.CH;
    
    % 1. Interpolación analógica a digital (ADC) idéntica a la del Receiver
    tin = (0:length(y)-1)./(cfg_s.BR*OVS_CH);
    tout = (0:1/(cfg_s.BR*OVS_DSP):tin(end));
    dsp_in = interp1(tin, y, tout, 'linear', 'extrap');
    
    % 2. AGC digital idéntico
    agc_target = 0.3; 
    agc_out = dsp_in ./ std(dsp_in) * agc_target;
    
    % 3. Extraemos el bloque final de la señal (donde el algoritmo ya convergió)
    N_symbs_steady = 2000; % Símbolos finales estables a graficar
    N_samps_steady = N_symbs_steady * OVS_DSP;
    
    if length(agc_out) > N_samps_steady
        agc_steady = agc_out(end - N_samps_steady + 1 : end);
    else
        agc_steady = agc_out;
    end
    
    % 4. Filtrado con la respuesta impulsiva convergida (htaps)
    ffe_out_steady = filter(htaps, 1, agc_steady);
    
    % Descartamos el transitorio de carga inicial del filtro FIR
    ffe_out_steady = ffe_out_steady(length(htaps):end);
    
    % 5. Formateo y graficación del diagrama de ojo
    span_eye = 2; % Duración de ventana de 2 símbolos
    Ns_eye = span_eye * OVS_DSP;
    Neye = floor(length(ffe_out_steady)/Ns_eye) * Ns_eye;
    y_eye = ffe_out_steady(1:Neye);
    
    eye_I = reshape(real(y_eye), Ns_eye, []);
    eye_Q = reshape(imag(y_eye), Ns_eye, []);
    
    t_eye = (0:Ns_eye-1) / (cfg_s.BR * OVS_DSP);
    t_eye = t_eye / (1/cfg_s.BR); % Normalizado a tiempo de símbolo Ts
    
    figure('Name', 'Equalized Eye Diagram', 'Color', 'w')
    subplot(2,1,1);
    plot(t_eye, eye_I, 'b', 'LineWidth', 0.6);
    grid on; box on;
    xlim([0 span_eye]);
    xlabel('Tiempo normalizado [T_s]');
    ylabel('Amplitud (I)');
    title('Diagrama de Ojo Ecualizado (Steady-State) - Rama I');
    
    subplot(2,1,2);
    plot(t_eye, eye_Q, 'r', 'LineWidth', 0.6);
    grid on; box on;
    xlim([0 span_eye]);
    xlabel('Tiempo normalizado [T_s]');
    ylabel('Amplitud (Q)');
    title('Diagrama de Ojo Ecualizado (Steady-State) - Rama Q');

    % =========================================================================
    % PANEL 2: ANÁLISIS DE RECUPERACIÓN DE PORTADORA (FCR / PLL)
    % =========================================================================
    figure('Name', 'Desempeño del FCR (PLL)', 'Color', 'w', 'Position', [150, 150, 1000, 600]);
    sgtitle('Dinámica del Lazo de Recuperación de Portadora', 'FontSize', 15, 'FontWeight', 'bold');

    % % 1. Evolución de la Fase Acumulada
    % subplot(2, 2, 1);
    % plot(o_rx.phase_acc_log, 'LineWidth', 1.5, 'Color', '#77AC30');
    % grid on; box on;
    % xlabel('Muestras Logueadas (x10 Símbolos)', 'FontWeight', 'bold'); 
    % ylabel('Fase Acumulada [rad]', 'FontWeight', 'bold');
    % title('Trayectoria de Fase del NCO');



    % 1. Evolución de la rama integral del DPLL
    subplot(2, 2, 1);
    
    freq_acc_MHz = acc_log * cfg_s.BR / (2*pi) / 1e6;
    
    plot(freq_acc_MHz, 'LineWidth', 1.5);
    hold on;
    
    yline(cfg_s.delta_freq/1e6, 'k--', ...
        'Offset inyectado', ...
        'LineWidth', 1.5);
    
    grid on;
    box on;
    hold off;
    
    xlabel('Muestras logueadas (x10 símbolos)', ...
        'FontWeight', 'bold');
    
    ylabel('Rama integral [MHz]', ...
        'FontWeight', 'bold');
    
    title('Rama integral del DPLL');


    % 2. Estimación de Frecuencia (Derivada de la fase)
    subplot(2, 2, 2);
    FRAME_LOG_1x = 10; % Tasa a la que logueamos en el Receiver
    delta_t = FRAME_LOG_1x / cfg_s.BR; % Paso temporal entre muestras logueadas
    
    % Frecuencia instantánea [Hz] = (Derivada de Fase / 2*pi)
    freq_est = diff(o_rx.phase_acc_log) / (2 * pi * delta_t);
    
    % Aplicamos un promediado móvil para suavizar el ruido térmico
    window_size = 100;
    freq_est_smooth = filter(ones(1, window_size)/window_size, 1, freq_est);
    
    plot(freq_est_smooth / 1e6, 'LineWidth', 1.5, 'Color', '#A2142F');
    hold on;
    yline(cfg_s.delta_freq / 1e6, 'k--', 'Offset Inyectado (\Delta f)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'center');
    grid on; box on; hold off;
    xlabel('Muestras Logueadas', 'FontWeight', 'bold'); 
    ylabel('Desvío de Frecuencia [MHz]', 'FontWeight', 'bold');
    title('Seguimiento de Frecuencia del PLL');

    % 3. Constelación ANTES del FCR
    subplot(2, 2, 3);
    % Reconstruimos matemáticamente lo que salía del FFE antes de la derotación:
    % S_raw = S_rotado * exp(+j * Fase_NCO)
    slicer_in_raw_log = slicer_in_log .* exp(1j * o_rx.phase_acc_log);
    
    plot(real(slicer_in_raw_log(end-2000:end)), imag(slicer_in_raw_log(end-2000:end)), '.', 'Color', '#7E2F8E', 'MarkerSize', 6);
    grid on; box on; axis square;
    xlabel('In-Phase (I)', 'FontWeight', 'bold'); 
    ylabel('Quadrature (Q)', 'FontWeight', 'bold');
    title('ANTES del FCR (Salida del FFE)');

    % 4. Constelación DESPUÉS del FCR
    subplot(2, 2, 4);
    plot(real(slicer_in_log(end-2000:end)), imag(slicer_in_log(end-2000:end)), '.', 'Color', '#D95319', 'MarkerSize', 6);
    grid on; box on; axis square;
    xlabel('In-Phase (I)', 'FontWeight', 'bold'); 
    ylabel('Quadrature (Q)', 'FontWeight', 'bold');
    title('DESPUÉS del FCR (Entrada al Slicer)');
end
% Graficos Temporales
if cfg_s.en_plots
    
    num_symbs_plot = 50; % ventana de observacion
    % num_samps_plot = num_symbs_plot * cfg_s.OVS;
    % 
    % T_s = 1 / cfg_s.BR;     
    % T_OVS = T_s / cfg_s.OVS;        
    % 
    % t_s = (0:num_symbs_plot-1) * T_s; % vectores de tiempo
    % t_ovs = (0:num_samps_plot-1) * T_OVS;
    num_samps_ch_plot = num_symbs_plot * cfg_s.OVS.CH;
    
    T_s  = 1 / cfg_s.BR;     
    T_ch = T_s / cfg_s.OVS.CH;        
    
    t_s  = (0:num_symbs_plot-1) * T_s;
    t_ch = (0:num_samps_ch_plot-1) * T_ch;    
    
    %%Transmisor
    figure('Name', 'Analisis Temporal del Enlace (I & Q)', 'Position', [100, 100, 900, 700]);
    
    % Simbolos (ak)
    subplot(4,1,1);
    stem(t_s, real(ak(1:num_symbs_plot)), 'filled', 'MarkerSize', 5, 'Color', 'b');
    hold on;
    stem(t_s, imag(ak(1:num_symbs_plot)), 'filled', 'MarkerSize', 5, 'Color', 'r');
    title('Símbolos Generados M-QAM');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;
    
    % Simbolos sobremuestreados (ak)
    subplot(4,1,2);
    % stem(t_ovs, real(ak_up(1:num_samps_plot)), 'filled', 'MarkerSize', 5, 'Color', 'b');
    stem(t_ch, real(ak_up(1:num_samps_ch_plot)), 'filled', 'MarkerSize', 5, 'Color', 'b');
    hold on;
    % stem(t_ovs, imag(ak_up(1:num_samps_plot)), 'filled', 'MarkerSize', 5, 'Color', 'r');
    stem(t_ch, imag(ak_up(1:num_samps_ch_plot)), 'filled', 'MarkerSize', 5, 'Color', 'r');
    title('Símbolos Generados M-QAM upsampler');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;
    
    % salida del transmisor (o_tx)
    subplot(4,1,3);
    % plot(t_ovs, real(o_tx(1:num_samps_plot)), 'b', 'LineWidth', 1.5);
    plot(t_ch, real(o_tx(1:num_samps_ch_plot)), 'b', 'LineWidth', 1.5);
    hold on;
    % plot(t_ovs, imag(o_tx(1:num_samps_plot)), 'r', 'LineWidth', 1.5);
    plot(t_ch, imag(o_tx(1:num_samps_ch_plot)), 'r', 'LineWidth', 1.5);
    title('Salida del Transmisor (Señal Conformada)');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;
    
    % salida del canal
    subplot(4,1,4);
    % plot(t_ovs, real(o_canal(1:num_samps_plot)), 'b', 'LineWidth', 1.2);
    plot(t_ch, real(o_canal(1:num_samps_ch_plot)), 'b', 'LineWidth', 1.2);
    hold on;
    % plot(t_ovs, imag(o_canal(1:num_samps_plot)), 'r', 'LineWidth', 1.2);
    plot(t_ch, imag(o_canal(1:num_samps_ch_plot)), 'r', 'LineWidth', 1.2);
    title(sprintf('Salida del Canal (FIR + AWGN, Eb/No = %d dB)', cfg_s.EbNo));
    xlabel('Tiempo (s)');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;
    
    %%Receptor
    figure('Name', 'Analisis Temporal del Enlace (I & Q)', 'Position', [100, 100, 900, 700]);
    
    % Simbolos (ak)
    % Simbolos sobremuestreados (ak)
    subplot(2,1,1);
    % plot(t_ovs, real(y(1:num_samps_plot)), 'b', 'LineWidth', 1.2);
    plot(t_ch, real(y(1:num_samps_ch_plot)), 'b', 'LineWidth', 1.2);
    hold on;
    % plot(t_ovs, imag(y(1:num_samps_plot)), 'r', 'LineWidth', 1.2);
    plot(t_ch, imag(y(1:num_samps_ch_plot)), 'r', 'LineWidth', 1.2);
    title(sprintf('Salida del Canal (FIR + AWGN, Eb/No = %d dB)', cfg_s.EbNo));
    xlabel('Tiempo (s)');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;
    
    subplot(2,1,2);
    stem(t_s, real(yk(1:num_symbs_plot)), 'filled', 'MarkerSize', 5, 'Color', 'b');
    hold on;
    stem(t_s, imag(yk(1:num_symbs_plot)), 'filled', 'MarkerSize', 5, 'Color', 'r');
    title('Símbolos Generados M-QAM');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;
    
end