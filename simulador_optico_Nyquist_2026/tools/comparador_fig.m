%% FIGURA EXTRA - COMPARACION RESPUESTA IMPULSIONAL FFE

FFE_imp  = load('FFE_impulso.mat');
FFE_leve = load('FFE_leve.mat');
FFE_mod  = load('FFE_moderada.mat');
FFE_agr  = load('FFE_agresiva.mat');

eje_taps = 1:length(FFE_imp.htaps_finales_ffe);

figure('Name', 'Comparación FFE - Respuesta Impulsional', ...
       'Color', 'w', ...
       'Position', [200 100 900 550]);

stem(eje_taps, abs(FFE_imp.htaps_finales_ffe), ...
     'LineWidth', 1.2, ...
     'DisplayName', 'Impulso');

hold on;

stem(eje_taps, abs(FFE_leve.htaps_finales_ffe), ...
     'LineWidth', 1.2, ...
     'DisplayName', 'Leve');

stem(eje_taps, abs(FFE_mod.htaps_finales_ffe), ...
     'LineWidth', 1.2, ...
     'DisplayName', 'Moderada');

stem(eje_taps, abs(FFE_agr.htaps_finales_ffe), ...
     'LineWidth', 1.2, ...
     'DisplayName', 'Agresiva');

grid on;
xlabel('Índice del Tap');
ylabel('|h_{FFE}[n]|');
title('Respuesta Impulsional Final del FFE');
legend('Location','best');

hold off;


%% FIGURA EXTRA - COMPARACION RESPUESTA EN FRECUENCIA FFE


FFE_imp  = load('FFE_impulso.mat');
FFE_leve = load('FFE_leve.mat');
FFE_mod  = load('FFE_moderada.mat');
FFE_agr  = load('FFE_agresiva.mat');

figure('Name', 'Comparación FFE - Frecuencia', ...
       'Color', 'w', ...
       'Position', [200 100 900 550]);

plot(FFE_imp.f_ffe/1e9, ...
     20*log10(abs(FFE_imp.H_ffe_final) + eps), ...
     'LineWidth', 1.8, ...
     'DisplayName', 'Impulso');

hold on;

plot(FFE_leve.f_ffe/1e9, ...
     20*log10(abs(FFE_leve.H_ffe_final) + eps), ...
     'LineWidth', 1.8, ...
     'DisplayName', 'Leve - BW = 17.75 GHz');

plot(FFE_mod.f_ffe/1e9, ...
     20*log10(abs(FFE_mod.H_ffe_final) + eps), ...
     'LineWidth', 1.8, ...
     'DisplayName', 'Moderada - BW = 16 GHz');

plot(FFE_agr.f_ffe/1e9, ...
     20*log10(abs(FFE_agr.H_ffe_final) + eps), ...
     'LineWidth', 1.8, ...
     'DisplayName', 'Agresiva - BW = 15.5 GHz');

grid on;
xlabel('Frecuencia [GHz]');
ylabel('|H_{FFE}(f)| [dB]');
title('Respuesta en Frecuencia Final del FFE');
legend('Location','best');

hold off;