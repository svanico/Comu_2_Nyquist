clear; clc; close all;


%% Detector 4th Power
load('ej3_resultados_4th.mat');

figure;
hold on;
set(gca,'XScale','log');
grid on;

for i = 1:length(Kp_vec)

    semilogx(f_jitter_vec, ...
             squeeze(penalidad_SNR_dB(1,i,:)), ...
             '-o', ...
             'LineWidth', 1.5, ...
             'DisplayName', sprintf('K_p = %.0e', Kp_vec(i)));

end

xlabel('Frecuencia de Jitter [Hz]');
ylabel('Penalidad de SNR [dB]');
title('Penalidad de SNR vs Frecuencia de Jitter - Detector 4th Orden');

legend('Location','best');

xlim([2e5 5e8]);
ylim([0 1.13]);

hold off;


%% Detector Decision-Directed
% load('ej3_resultados_DD.mat');

% figure;
% hold on;
% grid on;
% 
% for i = 1:length(Kp_vec)
% 
%     semilogx(f_jitter_vec, ...
%              squeeze(penalidad_SNR_dB(2,i,:)), ...
%              '-o', ...
%              'LineWidth', 1.5, ...
%              'DisplayName', sprintf('K_p = %.0e', Kp_vec(i)));
% 
% end
% 
% xlabel('Frecuencia de Jitter [Hz]');
% ylabel('Penalidad de SNR [dB]');
% title('Penalidad de SNR vs Frecuencia de Jitter - Detector DD');
% 
% legend('Location','best');
% 
% xlim([2e5 5e8]);
% ylim([0 1.13]);
% 
% hold off;