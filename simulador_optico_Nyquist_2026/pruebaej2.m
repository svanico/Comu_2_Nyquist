clear; clc; close all;

%% Cargar resultados ya calculados
load('ej2_penalidad_snr.mat');

%% Gráfico de penalidad suavizado

figure('Name','Ejercicio 2 - Penalidad de SNR');

% Eje x numérico para poder interpolar los casos
x_cases = 1:length(ch_names);

% Eje x denso para dibujar una curva suave
x_suave = linspace(1, length(ch_names), 300);

% Interpolación suave entre los puntos simulados
penalidad_suave = interp1(x_cases, penalidad_dB, x_suave, 'pchip');

% Curva suave
plot(x_suave, penalidad_suave, '-', ...
     'LineWidth', 2, ...
     'DisplayName', 'Tendencia interpolada');
hold on;

% Puntos reales simulados
plot(x_cases, penalidad_dB, 'o', ...
     'LineWidth', 2, ...
     'MarkerSize', 8, ...
     'DisplayName', 'Puntos simulados');

grid on;
xticks(x_cases);
xticklabels(ch_names);

xlabel('Caso de canal');
ylabel('Penalidad de SNR [dB]');
title(sprintf('Penalidad de SNR a BER = %.0e', BER_obj));

xlim([1 length(ch_names)]);
ylim([0 max(penalidad_dB)*1.2]);

legend('Location','northwest');