clear; clc; close all;

% Config base
cfg_s = struct();
cfg_s.en_n         = 1;    % Habilita AWGN
cfg_s.en_ch_filter = 1;    % Habilita fir del canal
cfg_s.pos_n        = 1;    % 1:ruido coloreado, 0:blanco    (por como pusimos el canal, metés el ruido antes del filtro del canal. Entonces el ruido también pasa por el filtro y queda coloreado.)
cfg_s.Lsymbs       = 1e6;  % Cantidad de simbolos
cfg_s.rolloff      = 0.1;  % Exceso de ancho de banda
% cfg_s.OVS          = 2;    % Sobremuestreo
cfg_s.OVS.CH  = 4;   % Sobremuestreo del transmisor/canal
cfg_s.OVS.DSP = 2;   % Sobremuestreo del DSP/LMS


cfg_s.BR           = 32e9; % Baud rate
cfg_s.M            = 16;    % Orden de modulacion
cfg_s.NTAPS_RRC    = 101;  
cfg_s.NTAPS_FIR    = 101;

%receptor parametros
cfg_s.NTAPS_ffe    = 51;
cfg_s.time_cma     = 50e3;  %tiempo del cma
% cfg_s.R_CMA        = 13.2;  %cte de comparacion del cma usamos la de 16
cfg_s.cma_step = 1e-3;
cfg_s.dd_step = 1e-4;
cfg_s.leak = 0e-6;


cfg_s.ch_bw        = 32e9; % BW del canal
cfg_s.EbNo         = 20;   %valor de ebno para los graficos 

cfg_s.en_plots     = 0;     % habilitar o no los graficos temporales
cfg_s.en_curva_ber = 1;     % habilitar o no la curva ber

%%llegamos hasta la curva ber

cfg_s.en_debug_plots = 0;   % habilita herramientas de debugging

cfg_s.debug_psd      = 0;   % PSD
cfg_s.debug_eye      = 0;   % diagrama de ojo
cfg_s.debug_const    = 1;   % constelacion
cfg_s.debug_Nsymbs   = 1e6; % cantidad de simbolos para graficar



% Vector de Eb/No, Lsymbs y M a evaluar
EbNo_BER    = 0:2:16;
L_vec       = [1e4, 1e4, 1e4, 1e5, 1e6, 1e7, 1e6, 1e6, 1e6]; %vector de símbolos variable para cada EbNo
M_vec       = [4 16];

% Llamada a la función superior de simulación
if cfg_s.en_curva_ber

    [ber_simulada, errores_totales] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec);
    
end

%% Config bloques

%Transmisor
o_tx_s = struct();
o_tx_s = transmisor_QAM(cfg_s);
ak     = o_tx_s.ak;
ak_up  = o_tx_s.ak_ovs;
o_tx   = o_tx_s.o_tx;
rrc    = o_tx_s.rrc;

%Canal
i_canal = o_tx;
o_canal = channel(i_canal,cfg_s);

%Receptor
i_rx = o_canal;
o_rx = struct();
o_rx = Receiver(i_rx,cfg_s,o_tx_s);
y = o_rx.y;
yk = o_rx.o_dws;
ak_hat = o_rx.ak_hat;

%Ber checker
[ber,errors]  = BER_checker(ak_hat,ak, cfg_s.M, 0);
o_data_rx.ber = ber;
o_data_rx.errors = errors;


%% Herramientas de debugging: PSD, diagrama de ojo y constelacion

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
        eye_Q = reshape(imag(y_eye), Ns_eye, []);    %imag(y_eye)  => rama Q y reshape me da una matriz donde cada columna es una traza del ojo

        % t_eye = (0:Ns_eye-1) / fs;
        t_eye = (0:Ns_eye-1) / fs_ch;
        t_eye = t_eye / (1/cfg_s.BR); % tiempo normalizado a Ts

        figure('Name','Debugging - Diagrama de ojo');

        subplot(2,1,1);
        plot(t_eye, eye_I, 'LineWidth', 0.8);    %grafica todas las columnas superpuestas. Eso forma el diagrama de ojo
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
            'DisplayName','Muestras RX antes del slicer');  %Grafica las muestras recibidas después del filtro y del downsampler, pero antes del slicer. las muestras yk(las nubes)

        plot(real(ak_hat(1:Nconst)), imag(ak_hat(1:Nconst)), 'x', ...
            'DisplayName','Símbolos decididos');   %Grafica los símbolos después del slicer.

        grid on;
        axis equal;
        xlabel('In-Phase');
        ylabel('Quadrature');
        title(sprintf('Constelacion - M = %d, Eb/No = %d dB', cfg_s.M, cfg_s.EbNo));
        legend('Location','best');

    end

end



%% Graficos Temporales
if cfg_s.en_plots
    
    num_symbs_plot = 50; %ventana de observacion
    % num_samps_plot = num_symbs_plot * cfg_s.OVS;
    % 
    % T_s = 1 / cfg_s.BR;     
    % T_OVS = T_s / cfg_s.OVS;        
    % 
    % t_s = (0:num_symbs_plot-1) * T_s; %vectores de tiempo
    % t_ovs = (0:num_samps_plot-1) * T_OVS;

    num_samps_ch_plot = num_symbs_plot * cfg_s.OVS.CH;
    
    T_s  = 1 / cfg_s.BR;     
    T_ch = T_s / cfg_s.OVS.CH;        
    
    t_s  = (0:num_symbs_plot-1) * T_s;
    t_ch = (0:num_samps_ch_plot-1) * T_ch;    
    
    %%Transmisor
    figure('Name', 'Analisis Temporal del Enlace (I & Q)', 'Position', [100, 100, 900, 700]);
    
    %Simbolos (ak)
    subplot(4,1,1);
    stem(t_s, real(ak(1:num_symbs_plot)), 'filled', 'MarkerSize', 5, 'Color', 'b');
    hold on;
    stem(t_s, imag(ak(1:num_symbs_plot)), 'filled', 'MarkerSize', 5, 'Color', 'r');
    title('Símbolos Generados M-QAM');
    ylabel('Amplitud');
    legend('Rama I (Real)', 'Rama Q (Imaginaria)', 'Location', 'best');
    grid on; hold off;

     %Simbolos sobremuestreados (ak)
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
    
    %salida del transmisor (o_tx)
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
    
    %salida del canal
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
    
    %Simbolos (ak)

    %Simbolos sobremuestreados (ak)
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