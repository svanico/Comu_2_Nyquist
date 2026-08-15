% clear; clc; close all;
% rng(1);

%% 1. Parámetros generales
cfg_s = struct();
cfg_s.BR              = 32e9;       % Baud rate 
cfg_s.M               = 16;         % Orden de modulacion
cfg_s.Lsymbs          = 1e6;        % Cantidad de simbolos
cfg_s.rolloff         = 0.6;        % Exceso de ancho de banda
cfg_s.EbNo            = 12;         % Valor de EbNo para los graficos temporales/debugging

% Sobremuestreo
cfg_s.OVS.CH          = 4;          % Sobremuestreo del transmisor/canal
cfg_s.OVS.DSP         = 2;          % Sobremuestreo del DSP/LMS
cfg_s.NTAPS_RRC       = 51;         % Filtros transmisor

cfg_s.en_carrier_recovery = 1;      % Habilita corrección en receptor

%% 2. Canal y ruido
cfg_s.en_ch_filter    = 1;          % Habilita filtro del canal
cfg_s.en_n            = 1;          % Habilita AWGN
cfg_s.pos_n           = 0;          % 1:ruido coloreado, 0:blanco
cfg_s.NTAPS_FIR       = 101;        % Coeficientes del canal
cfg_s.ch_bw           = 16e9;    % Ancho de banda del canal (Moderada)

%% 3. Errores de portadora
cfg_s.en_c_error      = 1;          % Habilita errores de portadora 
% Errores Estáticos 
cfg_s.delta_freq      = 0e6;       % Offset del LO
cfg_s.phase_offset    = 0/180*pi;  % Error de fase
cfg_s.LW              = 0e3;        % Ancho de linea [Hz] -> Ruido de fase

% Fluctuaciones
cfg_s.freq_fluct_amp  = 0;
cfg_s.freq_fluct_freq = 0e3;

cfg_s.phase_tone_amp  = 0.1;
cfg_s.phase_tone_freq = 500e3;

%% 4. Receptor (Ecualizador y Recuperador de Portadora)
% Parámetros del Ecualizador (FFE)
cfg_s.NTAPS_ffe       = 51;         % Cantidad de coeficientes del ecualizador
cfg_s.cma_step        = 1e-3;       % Paso de adaptación para convergencia ciega (Reducir para modulaciones altas)
cfg_s.dd_step         = 1e-3;       % Paso de adaptación para seguimiento fino
cfg_s.leak            = 1e-7;       % Factor de pérdida (leakage)

% Parámetros del PLL y RFD
cfg_s.Kp              = 3e-3;       % Ganancia proporcional del PLL
cfg_s.Ki              = cfg_s.Kp/500; % Ganancia integral del PLL
cfg_s.rfd_gain        = 0;       % apagado

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
cfg_s.en_debug_plots  = 0;          % Habilita el llamado a debug_dashboard.m
cfg_s.en_plots_rx     = 0;          % Habilita métricas internas del receptor
cfg_s.debug_psd       = 0;          % Grafica Densidad Espectral de Potencia (PSD)
cfg_s.debug_eye       = 0;          % Grafica Diagrama de Ojo
cfg_s.debug_const     = 0;          % Grafica Constelación
cfg_s.debug_Nsymbs    = 1e6;        % Cantidad de simbolos para graficar

% Vectores para Curva BER (Si en_curva_ber = 1)
EbNo_BER              = 4:2:16;
M_vec                 = [16];
L_vec                 = 1e6 * ones(size(EbNo_BER));

% Ejecución en bucle (BER Sweep)
if cfg_s.en_curva_ber
    [ber_simulada, errores_totales] = curva_ber(cfg_s, EbNo_BER, L_vec, M_vec);
end

% ------------------------------------------------------------------------
% Ejecución de Caso Individual (Debugging)
% ------------------------------------------------------------------------
% fprintf(['\nCASO INDIVIDUAL: M = %d | EbNo = %.1f dB | ' ...
%          'Lsymbs = %d | rfd_gain = %.1e\n'], ...
%         cfg_s.M, cfg_s.EbNo, cfg_s.Lsymbs, cfg_s.rfd_gain);
% 
% % 1. Transmisor
% o_tx_s  = transmisor_QAM(cfg_s);
% 
% % 2. Canal
% o_canal = channel(o_tx_s.o_tx, cfg_s);
% 
% % 3. Receptor
% o_rx    = Receiver(o_canal, cfg_s, o_tx_s.ak); 
% 
% % 4. Verificador de BER
% [ber, errors]  = BER_checker(o_rx.ak_hat_fixed, o_rx.ak_tx_aligned, cfg_s.M, 0);
% 
% 
% % SNR medida
% N_snr = min(1000, length(o_rx.error_base_log));
% 
% error_ss = o_rx.error_base_log(end-N_snr+1:end);
% 
% P_signal = mean(abs(o_tx_s.ak).^2);
% P_error  = mean(abs(error_ss).^2);
% 
% SNR_rx_dB = 10*log10(P_signal/P_error);
% 
% 
% 
% % 5. Impresión de resultados
% fprintf('\n--- RESULTADOS FINALES ---\n');
% fprintf('MSE Final Ecualizador : %.2f dB\n', o_rx.MSE);
% fprintf('Tasa de Error (BER)   : %.4e\n', ber);
% fprintf('Total de errores      : %d\n', errors);
% fprintf('SNR medida a la entrada del slicer = %.2f dB\n', SNR_rx_dB);
% 
% % 6. Gráficos
% debug(cfg_s, o_tx_s, o_canal, o_rx);
% 

% ------------------------------------------------------------------------
% EJERCICIO 3 - BARRIDO DE FRECUENCIA DE JITTER
% ------------------------------------------------------------------------

% Frecuencias de jitter a evaluar
f_jitter_vec = logspace(log10(500e3), log10(5e8), 10);   % 500 kHz a 500 MHz

% Reservamos memoria
SNR_jitter_dB = zeros(size(f_jitter_vec));
penalidad_SNR_dB = zeros(size(f_jitter_vec));


%%1. Transmisor
% No cambia con la frecuencia de jitter, por eso se genera una sola vez
o_tx_s = transmisor_QAM(cfg_s);


%%2. SNR DE REFERENCIA - SIN JITTER
cfg_ref = cfg_s;

cfg_ref.en_c_error = 0;

% Mantenemos la misma realización de ruido para comparar limpiamente
rng(2);

o_canal_ref = channel(o_tx_s.o_tx, cfg_ref);
o_rx_ref    = Receiver(o_canal_ref, cfg_ref, o_tx_s.ak);

% % SNR medida a la entrada del slicer
% N_snr = min(1000, length(o_rx_ref.error_base_log));
% 
% error_ss = o_rx_ref.error_base_log(end-N_snr+1:end);

% Medición de SNR desde el inicio de DD hasta el final
idx_snr_ini = floor(cfg_ref.t4_ffe_dd/10) + 1;

error_ss = o_rx_ref.error_base_log(idx_snr_ini:end);

P_signal = mean(abs(o_tx_s.ak).^2);
P_error  = mean(abs(error_ss).^2);

SNR_ref_dB = 10*log10(P_signal/P_error);

fprintf('\nSNR referencia sin jitter = %.2f dB\n', SNR_ref_dB);


%%3. BARRIDO DE FRECUENCIA DE JITTER

for k = 1:length(f_jitter_vec)

    % Copiamos configuración base
    cfg_jit = cfg_s;

    % Activamos errores de portadora
    cfg_jit.en_c_error = 1;

    % Dejamos solamente activo el jitter de fase
    cfg_jit.delta_freq      = 0;
    cfg_jit.phase_offset    = 0;
    cfg_jit.LW              = 0;
    cfg_jit.freq_fluct_amp  = 0;

    cfg_jit.phase_tone_amp  = 0.1;
    cfg_jit.phase_tone_freq = f_jitter_vec(k);


    % Misma realización de AWGN para todos los puntos
    rng(2);

    % Canal
    o_canal = channel(o_tx_s.o_tx, cfg_jit);

    % Receptor
    o_rx = Receiver(o_canal, cfg_jit, o_tx_s.ak);


    % SNR medida
% Medición de SNR desde el inicio de DD hasta el final
idx_snr_ini = floor(cfg_s.t4_ffe_dd/10) + 1;

error_ss = o_rx.error_base_log(idx_snr_ini:end);

    P_error = mean(abs(error_ss).^2);

    SNR_jitter_dB(k) = 10*log10(P_signal/P_error);


    % Penalidad respecto del caso sin jitter
    penalidad_SNR_dB(k) = SNR_ref_dB - SNR_jitter_dB(k);


    fprintf(['f_jitter = %.3e Hz | SNR = %.2f dB | ' ...
             'Penalidad = %.2f dB\n'], ...
             f_jitter_vec(k), ...
             SNR_jitter_dB(k), ...
             penalidad_SNR_dB(k));

end
%% 4. Gráfico de penalidad

figure;

semilogx(f_jitter_vec, penalidad_SNR_dB, '-o', ...
         'LineWidth', 1.5);

grid on;

xlabel('Frecuencia de Jitter [Hz]');
ylabel('Penalidad de SNR [dB]');

title(sprintf('Penalidad de SNR - K_p = %.1e', cfg_s.Kp));