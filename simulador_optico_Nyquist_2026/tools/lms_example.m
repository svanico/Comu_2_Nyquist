clear all
clc
close all;

%%
L = 200e3*2;
M = 16;
ovs_ch = 4;
ovs_ffe = 2;
dd_step = 1e-4;
cma_step = 1e-3;

BR = 32e9;
leak = 0e-6;

initital_phase = 0;
agc_taget = 0.3;
NTAPS_ffe = 51; 
R_CMA = 13.2;
time_cma = 50e3;

FRAME_LOG_1x = 10;
FRAME_LOG_2x = 10;

%% Symbs + PS
syms_dec = randi([0 M-1],L,1); %SIMBOLOS PAM2
syms = qammod(syms_dec, M, "gray");

symbs_up = upsample(syms,ovs_ch); % UPSAMPLE 
[h_taps_ps ,~] = root_raised_cosine(BR, BR*ovs_ch, 0.1, 100, 0.);
ps_out = filter(h_taps_ps,1,symbs_up); 

%% Channel
ch_out = filter(fir1(10,0.15),1,ps_out);
noise = randn(length(ch_out),1) + 1j.*randn(length(ch_out),1);
ch_out = ch_out + 0.1.*noise;

%% Anti Alias Filter
[h_taps_ps ,~] = root_raised_cosine(BR, BR*ovs_ch, 0.1, 100, 0.);
aaf_out = filter(h_taps_ps,1, ch_out);

%% ADC
tin=(0:length(aaf_out)-1)./(BR*ovs_ch);
tout=(0:1/(BR*ovs_ffe):tin(end)) ; 
dsp_in = interp1(tin,aaf_out,tout,'linear','extrap');

%% Digital AGC
agc_out = dsp_in ./ std(dsp_in) * agc_taget;

%% EQ
htaps = zeros(NTAPS_ffe,1);
htaps(floor(NTAPS_ffe/2)-1) = 1; %IMPULSO AL MEDIO

buffer_filter = zeros(NTAPS_ffe,1); %%BUFFER


%%Variables to logging
ffe_out_log = zeros(ceil(L*ovs_ffe/FRAME_LOG_2x),1);
error_log = zeros(ceil(L/FRAME_LOG_1x),1);
slicer_in_log = zeros(ceil(L/FRAME_LOG_1x),1);

for idx=1:length(agc_out)

    buffer_filter(2:end) = buffer_filter(1:end-1);
    buffer_filter(1) = agc_out(idx);
    ffe_out = htaps.'*buffer_filter;

    if mod(idx,ovs_ffe)==0
        idx_new = ceil(idx/ovs_ffe);
        slicer_in = ffe_out;
        slicer_out = slicer_QAM_(slicer_in,M);
        % slicer_out = QAM_gen(slicer_in,M);            %quise probar con nuestro generador de QAM y no anduvo xd


        if idx_new<time_cma
            error =  slicer_in*(abs( slicer_in).^2 - R_CMA); 
            step = dd_step;
        else
            error =  slicer_in - slicer_out;
            step = cma_step;
        end
    
        htaps = (1-leak)*htaps - step*error*conj(buffer_filter);

        if mod(idx_new,FRAME_LOG_1x)==0
            error_log(idx_new/FRAME_LOG_1x) = error;
            slicer_in_log(idx_new/FRAME_LOG_1x) = slicer_in;
        end

    end

    if mod(idx,FRAME_LOG_2x)==0
        ffe_out_log(idx/FRAME_LOG_2x) = ffe_out;
    end

end

%%===========================================================
%% Figure 1: Error + Frequency response
%%===========================================================
N = 100;
figure(1)
set(gcf,'Color','w')
plot(10*log10(filter(ones(N,1)./N,1,abs(error_log).^2)),'LineWidth',2)
grid on
box on
xlabel('Iteration','Interpreter','latex','FontSize',14)
ylabel('Error Power [dB]','Interpreter','latex','FontSize',14)
title('MSE Evolution','Interpreter','latex','FontSize',14)

figure(1231312)
subplot(2,1,1)
stem(htaps,'LineWidth',2);
grid on
box on
xlabel('#','Interpreter','latex','FontSize',14)
ylabel('Amplitude','Interpreter','latex','FontSize',14)
title('FFE Time Impulse Response','Interpreter','latex','FontSize',14)

subplot(2,1,2)

NFFT = 4096;
Fs = BR*ovs_ffe;

H = fft(htaps,NFFT);
H = H(1:NFFT/2);
f = linspace(0,Fs/2,NFFT/2);

plot(f/1e9,20*log10(abs(H)+1e-12),'LineWidth',2)
grid on
box on
xlabel('Frequency [GHz]','Interpreter','latex','FontSize',14)
ylabel('Magnitude [dB]','Interpreter','latex','FontSize',14)
title('FFE Frequency Response','Interpreter','latex','FontSize',14)

%%===========================================================
%% Figure 2: Constellation
%%===========================================================

figure(2)
set(gcf,'Color','w')

subplot(2,1,1)
plot(real(slicer_in_log),'.','MarkerSize',8)
grid on
box on
xlabel('Symbol Index','Interpreter','latex','FontSize',14)
ylabel('In-Phase','Interpreter','latex','FontSize',14)
title('Real Part','Interpreter','latex','FontSize',14)

subplot(2,1,2)
plot(imag(slicer_in_log),'.','MarkerSize',8)
grid on
box on
xlabel('Symbol Index','Interpreter','latex','FontSize',14)
ylabel('Quadrature','Interpreter','latex','FontSize',14)
title('Imaginary Part','Interpreter','latex','FontSize',14)

%% MSE
MSE = 10*log10(mean(error_log(end-10000:end).^2));
fprintf('MSE = %.2f dB\n',MSE);