clear; clc; close all;

kp1 = load('penalidad_Kp_1e-02.mat');
kp2 = load('penalidad_Kp_1e-03.mat');
kp3 = load('penalidad_Kp_1e-04.mat');
kp4 = load('penalidad_Kp_1e-05.mat');

figure;

% Primera curva: esto fija el eje X logarítmico
semilogx(kp1.f_jitter_vec, kp1.penalidad_SNR_dB, '-o', ...
    'LineWidth', 1.5, 'DisplayName', 'K_p = 1e-2');

hold on;

semilogx(kp2.f_jitter_vec, kp2.penalidad_SNR_dB, '-o', ...
    'LineWidth', 1.5, 'DisplayName', 'K_p = 1e-3');

semilogx(kp3.f_jitter_vec, kp3.penalidad_SNR_dB, '-o', ...
    'LineWidth', 1.5, 'DisplayName', 'K_p = 1e-4');

semilogx(kp4.f_jitter_vec, kp4.penalidad_SNR_dB, '-o', ...
    'LineWidth', 1.5, 'DisplayName', 'K_p = 1e-5');

grid on;
xlabel('Frecuencia de Jitter [Hz]');
ylabel('Penalidad de SNR [dB]');
title('Penalidad de SNR vs Frecuencia de Jitter - Detector DD');
legend('Location','best');

xlim([5e5 5e8]);
ylim([0 2.5]);

hold off;