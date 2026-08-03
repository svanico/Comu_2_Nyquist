clc;
close all;
clear all;
%%
M =16;
N = 300000; %largo de simulacion [simbolos]
EbNo_dB = 15;
BR = 32e9;
k = log2(M);
REFRESH_RATE = 1000;
%%errores de portadora
theta_est = deg2rad(45); %Error estatico de fase en grados 
offset_freq = 4.3e9; % offset de portadora [hz]

%%DPLL config
dpll_on =0;
rfd_on =1;

kp = 1e-2;
ki  = 1e-5;
rfd_gain = 1e-3;
detector_type = 2; %%0: DD | 1: V4; 

th_low = (sqrt(2) + sqrt(10) )/2;
th_high = (sqrt(10) + sqrt(18) )/2;

%%Timers
Ndisc =fix(0.8*N);
dpll_timer_on = 0.3;
rfd_timer_off = 0.6;
dpll_timer_dd = 0.7;

%% ---------------- 1) Generacion de simbolos QAM (Gray) ------------------
B = randi([0 1], N, k);
sym_vec = qam_mod(B,M, 0);

% plot(real(sym_vec),imag(sym_vec),'.');
%% ---------------- 2) Canal: AWGN ---------------------
EsNo_dB = EbNo_dB + 10*log10(k);
Es = mean(abs(sym_vec).^2);
noise_vec = sqrt(Es) * (randn(N,1) + 1j*randn(N,1))/sqrt(2) * 10^(-EsNo_dB/20);

%% ---------------- 3) Canal:errores de portadora --------------------
t  = (0:N-1).'./BR; %esto va divido BR, pero en realidad es la frecuencia de muestreo del simulador en este punto
phase_vec = theta_est + 2*pi*offset_freq*t ;

rx_signal = sym_vec  .* exp(1j*phase_vec) + noise_vec;

% plot(real(rx_signal),imag(rx_signal),'.');

%% ---------------- 4) Compensacion digital --------------------
y =zeros(N,1);
e =zeros(N,1);
acc = zeros(N,1);
nco_out = 0;
last_detection = 0;
last_angle = 0;
angle_curr = 0;
for i = 1:N
        
    y(i) = rx_signal(i) .* exp(-1j*nco_out); %%correccion con la salida del NCO
    d     = slicer_QAM_(y(i),M); %% salida del slicer.

    y_mod = abs(y(i));

    if i> fix(dpll_timer_on*N)
        dpll_on = 1;
    end

    if i> fix(rfd_timer_off*N)
        rfd_on = 0;
    end

     if i> fix(dpll_timer_dd*N)
        detector_type = 0;
    end

   if (dpll_on)
       if (detector_type==0)
            e(i) = imag(conj(d) * y(i)) / (abs(y(i)) * abs(d));
        elseif (detector_type==1)
    
            if (y_mod < th_low || y_mod > th_high)
              e(i) = angle((y(i).*exp(-1j*pi/4))^4) /4;
            end
        elseif (detector_type==2)
            if (y_mod < th_low || y_mod > th_high)
                e(i) = mod(angle(y(i)),pi/2) - pi/4;
            end
       end
   else
       e(i) = 0;
   end


   if (rfd_on)

        if (y_mod < th_low || y_mod > th_high) %% SI EL SIMBOLO ACTUAL ES QPSK
            angle_curr = mod( angle(y(i)) ,pi/2) - pi/4;
            if (last_detection) %% SI EL SIMBOLO ANTERIOR ES QPSK

                 diff_angle = angle_curr - last_angle;

                 if (abs(diff_angle)>pi/4) %%SI LOS DOS SIMBOLOS CONSECUTIVOS VARIARON MAS DE PI/4 (WRAPPEADOS)
                     rfd_gain_value = -sign(diff_angle) * rfd_gain;
                 else
                     rfd_gain_value =0;
                 end

                 last_angle = angle_curr;
                 last_detection = 1;
            else
                 last_angle = angle_curr;
                 last_detection = 1;
            end

        else
           last_detection =0;
           rfd_gain_value = 0;
        end
   else
       rfd_gain_value = 0;
   end

   if (i>1)
        acc(i) = acc(i-1) + ki *  e(i) + rfd_gain_value;
   end

   nco_in = acc(i) + kp * e(i);
   nco_out = nco_out + nco_in;

   if (mod(i,REFRESH_RATE)==0)
        figure(12312312)

       subplot(1,2,1)
       plot(real(y(i-1000+1:i)), imag(y(i-1000+1:i)),'.')
       grid on 

       subplot(1,2,2)
       plot(acc/(2*pi) * BR / 1e6, 'LineWidth',2)
       ylabel('Rama Integral [MHz]')
       grid on

       drawnow()
   end

end

%% ---------------- 5)  BER -----------------------------
idx  = Ndisc+1:N;                        

% --- BER con y sin PLL ---
Bhat_pll = qam_demod(y(idx), M);
Bhat_raw = qam_demod(rx_signal(idx), M);
Bref     = B(idx,:);

BER_pll = mean(Bhat_pll(:) ~= Bref(:));
BER_raw = mean(Bhat_raw(:) ~= Bref(:));
SER_pll = mean(any(Bhat_pll ~= Bref, 2));

%%  ---------------- 6)  CS CORRECTION
out_data_cut = y(idx);
sym_vec_cut = sym_vec(idx);
s_in.data_receive= out_data_cut;
s_in.stx= sym_vec_cut;
s_in.WINDOW_LEN=50;
s_in.M=M;
[s_out] = dinamic_CS_corrector(s_in);

B_pll_cs_corr = qam_demod(s_out.orx_cs_fixed,M);
BER_pll_cs_corr = mean(B_pll_cs_corr(:) ~= Bref(:));

%% FINAL PRINTS
fprintf('--------------------------------------------\n');
fprintf(' BER sin PLL  = %.4e\n', BER_raw);
fprintf(' BER con PLL  = %.4e   (SER = %.4e)\n', BER_pll, SER_pll);
fprintf(' BER con PLL y CS fix = %.4e \n', BER_pll_cs_corr);
fprintf('--------------------------------------------\n');