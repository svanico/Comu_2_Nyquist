clear; clc; close all;
<<<<<<< HEAD
=======

>>>>>>> tp1_ej1
%% 1. Parámetros generales
cfg_s = struct();
cfg_s.BR              = 32e9;       % Baud rate 
cfg_s.M               = 16;         % Orden de modulacion
cfg_s.Lsymbs          = 1e6;        % Cantidad de simbolos
cfg_s.rolloff         = 0.6;        % Exceso de ancho de banda
cfg_s.EbNo            = 16;         % Valor de EbNo para los graficos temporales/debugging

% Sobremuestreo
cfg_s.OVS.CH          = 4;          % Sobremuestreo del transmisor/canal
cfg_s.OVS.DSP         = 2;          % Sobremuestreo del DSP/LMS
cfg_s.NTAPS_RRC       = 101;         % Filtros transmisor

cfg_s.en_carrier_recovery = 1;      % Habilita corrección en receptor

%% 2. Canal y ruido
cfg_s.en_ch_filter    = 1;          % Habilita filtro del canal
cfg_s.en_n            = 1;          % Habilita AWGN
cfg_s.pos_n           = 0;          % 1:ruido coloreado, 0:blanco
cfg_s.NTAPS_FIR       = 51;        % Coeficientes del canal
cfg_s.ch_bw           = 17.75e9;    % Ancho de banda del canal (leve)

%% 3. Errores de portadora
cfg_s.en_c_error      = 1;          % Habilita errores de portadora 
% Errores Estáticos 
cfg_s.delta_freq      = 0e6;       % Offset del LO
cfg_s.phase_offset    = 30/180*pi;  % Error de fase
cfg_s.LW              = 0e3;        % Ancho de linea [Hz] -> Ruido de fase
% Fluctuaciones
cfg_s.freq_fluct_amp  = 0;
cfg_s.freq_fluct_freq = 0e3;
cfg_s.phase_tone_amp  = 0/180*pi;
cfg_s.phase_tone_freq = 0e6;
<<<<<<< HEAD
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
cfg_s.Ki              = cfg_s.Kp/500; % Ganancia integral

%% 5. CONFIGURACIÓN DE SIMULACIONES Y DEBUGGING
% --- Habilitación de Bloques de Evaluación ---
cfg_s.en_plots_rx     = 0;          % Análisis del receptor (MSE, FFE, Constelación)
cfg_s.en_plots        = 0;          % Habilitar graficos temporales (Tx/Rx)
cfg_s.en_curva_ber    = 1;          % Habilitar simulacion en cascada para la curva ber
% --- Herramientas de Debugging General ---
cfg_s.en_debug_plots  = 1;          % Habilita bloque entero de debugging
cfg_s.debug_psd       = 0;          % PSD
cfg_s.debug_eye       = 0;          % Diagrama de ojo
cfg_s.debug_const     = 1;          % Constelacion
cfg_s.debug_Nsymbs    = 1e6;        % Cantidad de simbolos para graficar
% --- Vectores para Curva BER ---
EbNo_BER              = 0:2:10;
=======

%% 4. Receptor (Ecualizador y Recuperador de Portadora)
% Parámetros del Ecualizador (FFE)
cfg_s.NTAPS_ffe       = 51;         % Cantidad de coeficientes del ecualizador
cfg_s.cma_step        = 0.2e-4;       % Paso de adaptación para convergencia ciega (Reducir para modulaciones altas)
cfg_s.dd_step         = 1e-4;       % Paso de adaptación para seguimiento fino
cfg_s.leak            = 1e-7;       % Factor de pérdida (leakage)

% Parámetros del PLL y RFD
cfg_s.Kp              = 1e-3;       % Ganancia proporcional del PLL
cfg_s.Ki              = cfg_s.Kp/1000; % Ganancia integral del PLL
cfg_s.rfd_gain        = 1e-4;       % Ganancia del detector de frecuencia

% Timers (FSM RX)
cfg_s.t1_rfd_frac    = 0.2;
cfg_s.t2_fcr_v4_frac = 0.3;
cfg_s.t3_fcr_dd_frac = 0.4;
cfg_s.t4_ffe_dd_frac = 0.6;

cfg_s.t1_rfd    = fix(cfg_s.t1_rfd_frac * cfg_s.Lsymbs);    % Pasa a Etapa 2 (Prende RFD)
cfg_s.t2_fcr_v4 = fix(cfg_s.t2_fcr_v4_frac * cfg_s.Lsymbs); % Pasa a Etapa 3 (FFE-CMA + RFD + FCR)
cfg_s.t3_fcr_dd = fix(cfg_s.t3_fcr_dd_frac * cfg_s.Lsymbs); % Pasa a Etapa 4 (FCR a DD, apaga RFD)
cfg_s.t4_ffe_dd = fix(cfg_s.t4_ffe_dd_frac * cfg_s.Lsymbs); % Pasa a Etapa 5 (FFE a DD LMS)

%% 5. CONFIGURACIÓN DE SIMULACIONES Y DEBUGGING

cfg_s.en_curva_ber    = 0;          % Habilitar simulacion en cascada para la curva ber

% Debug
cfg_s.en_plots_tx     = 0; 
cfg_s.en_plots_rx     = 1;            % Habilita métricas internas del receptor
cfg_s.debug_psd       = 0;            % Grafica Densidad Espectral de Potencia (PSD)
cfg_s.debug_eye       = 0;            % Grafica Diagrama de Ojo
cfg_s.debug_const     = 1;            % Grafica Constelación
cfg_s.debug_Nsymbs    = cfg_s.Lsymbs; % Cantidad de simbolos para graficar

% Vectores para Curva BER (Si en_curva_ber = 1)
EbNo_BER              = 0:2:12;
>>>>>>> tp1_ej1
M_vec                 = [4 16];
L_vec                 = 1e6 * ones(size(EbNo_BER));

% Ejecución en bucle (BER Sweep)
if cfg_s.en_curva_ber
    [ber_simulada, errores_totales] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec);
end
<<<<<<< HEAD


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
    ovs_ffe = o_rx.ovs_ffe;
    
    fprintf('\n--- Análisis de Convergencia del Ecualizador ---\n');
    fprintf('MSE Final LMS = %.2f dB\n', o_rx.MSE);
=======
>>>>>>> tp1_ej1

% Ejecución de Caso Individual (Debugging)
fprintf(['\nSimulacion: M = %d | EbNo = %.1f dB | ' ...
         'Lsymbs = %d | rfd_gain = %.1e\n'], ...
        cfg_s.M, cfg_s.EbNo, cfg_s.Lsymbs, cfg_s.rfd_gain);

% 1. Transmisor
o_tx_s  = transmisor_QAM(cfg_s);

% 2. Canal
o_canal = channel(o_tx_s.o_tx, cfg_s);

% 3. Receptor
o_rx    = Receiver(o_canal, cfg_s, o_tx_s.ak); 

% 4. Verificador de BER
[ber, errors]  = BER_checker(o_rx.ak_hat_fixed, o_rx.ak_tx_aligned, cfg_s.M, 0);

% 5. Impresión de resultados
fprintf('\n--- RESULTADOS FINALES ---\n');
fprintf('MSE de decisión : %.2f dB\n', o_rx.MSE);
fprintf('Tasa de Error (BER)   : %.4e\n', ber);
fprintf('Total de errores      : %d\n', errors);

% 6. Gráficos
debug(cfg_s, o_tx_s, o_canal, o_rx);