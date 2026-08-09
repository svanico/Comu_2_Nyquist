clear; clc; close all;
rng(1);

%% 1. Parámetros generales
cfg_s = struct();
cfg_s.BR              = 32e9;       % Baud rate 
cfg_s.M               = 16;         % Orden de modulacion
cfg_s.Lsymbs          = 1e6;        % Cantidad de simbolos
cfg_s.rolloff         = 0.9;        % Exceso de ancho de banda
cfg_s.EbNo            = 100;         % Valor de EbNo para los graficos temporales/debugging

% Sobremuestreo
cfg_s.OVS.CH          = 4;          % Sobremuestreo del transmisor/canal
cfg_s.OVS.DSP         = 2;          % Sobremuestreo del DSP/LMS
cfg_s.NTAPS_RRC       = 51;         % Filtros transmisor

cfg_s.en_carrier_recovery = 0;      % Habilita corrección en receptor

%% 2. Canal y ruido
cfg_s.en_ch_filter    = 0;          % Habilita filtro del canal
cfg_s.en_n            = 1;          % Habilita AWGN
cfg_s.pos_n           = 0;          % 1:ruido coloreado, 0:blanco
cfg_s.NTAPS_FIR       = 101;        % Coeficientes del canal
cfg_s.ch_bw           = 17.75e9;    % Ancho de banda del canal (Leve)

%% 3. Errores de portadora
cfg_s.en_c_error      = 0;          % Habilita errores de portadora 
% Errores Estáticos 
cfg_s.delta_freq      = 0e6;       % Offset del LO
cfg_s.phase_offset    = 30/180*pi;  % Error de fase
cfg_s.LW              = 0e3;        % Ancho de linea [Hz] -> Ruido de fase
% Fluctuaciones
cfg_s.freq_fluct_amp  = 0;
cfg_s.freq_fluct_freq = 0e3;
cfg_s.phase_tone_amp  = 0/180*pi;
cfg_s.phase_tone_freq = 0e6;

%% 4. Receptor (Ecualizador y Recuperador de Portadora)
% Parámetros del Ecualizador (FFE)
cfg_s.NTAPS_ffe       = 51;         % Cantidad de coeficientes del ecualizador
cfg_s.cma_step        = 1e-3;       % Paso de adaptación para convergencia ciega (Reducir para modulaciones altas)
cfg_s.dd_step         = 1e-4;       % Paso de adaptación para seguimiento fino
cfg_s.leak            = 1e-6;       % Factor de pérdida (leakage)

% Parámetros del PLL y RFD
cfg_s.Kp              = 1e-3;       % Ganancia proporcional del PLL
cfg_s.Ki              = cfg_s.Kp/500; % Ganancia integral del PLL
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
cfg_s.en_debug_plots  = 1;          % Habilita el llamado a debug_dashboard.m
cfg_s.en_plots_rx     = 1;          % Habilita métricas internas del receptor
cfg_s.debug_psd       = 1;          % Grafica Densidad Espectral de Potencia (PSD)
cfg_s.debug_eye       = 1;          % Grafica Diagrama de Ojo
cfg_s.debug_const     = 1;          % Grafica Constelación
cfg_s.debug_Nsymbs    = 1e6;        % Cantidad de simbolos para graficar

% Vectores para Curva BER (Si en_curva_ber = 1)
EbNo_BER              = 0:2:12;
M_vec                 = [4 16];
L_vec                 = 1e6 * ones(size(EbNo_BER));

% Ejecución en bucle (BER Sweep)
if cfg_s.en_curva_ber
    [ber_simulada, errores_totales] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec);
end

% ------------------------------------------------------------------------
% Ejecución de Caso Individual (Debugging)
% ------------------------------------------------------------------------
fprintf(['\nCASO INDIVIDUAL: M = %d | EbNo = %.1f dB | ' ...
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
fprintf('MSE Final Ecualizador : %.2f dB\n', o_rx.MSE);
fprintf('Tasa de Error (BER)   : %.4e\n', ber);
fprintf('Total de errores      : %d\n', errors);

% 6. Gráficos
debug(cfg_s, o_tx_s, o_canal, o_rx);