function [o_data_rx] = Receiver(i_rx,i_cfg_s,o_tx_s)
%Settings
    M = i_cfg_s.M;
    Lsymbs = i_cfg_s.Lsymbs;
    BR = i_cfg_s.BR;
    NTAPS = i_cfg_s.NTAPS_RRC;
    NTAPS_ffe = i_cfg_s.NTAPS_ffe;
    
    % OVS = i_cfg_s.OVS;
    ovs_ch = i_cfg_s.OVS.CH;
    ovs_ffe = i_cfg_s.OVS.DSP;

    fs = ovs_ch*BR;
    rolloff = i_cfg_s.rolloff;
    t0 = 0;
    
    agc_taget = 0.3;    %esto es a ojo (creemos)

    
    ak = o_tx_s.ak;

    time_cma =  i_cfg_s.time_cma ;
    % R_CMA   =   cfg_s.R_CMA;
    R_CMA = sqrt(mean(abs(ak(1:1000)).^4)/mean(abs(ak(1:1000)).^2));

    dd_step = i_cfg_s.dd_step;
    cma_step = i_cfg_s.cma_step;

    leak = i_cfg_s.leak;

    FRAME_LOG_1x = 10;  %guarda una muestra cada 10 símbolos.
    FRAME_LOG_2x = 10;


%Procesamiento
    % r = i_rx;
    % [~, rrc] = root_raised_cosine(BR,fs,rolloff,NTAPS,t0);
    % rrc = rrc ./ norm(rrc) * sqrt(OVS);
    
    % Lrrc = length(rrc);
    % delay = floor((Lrrc-1)/2); %calculo el delay para el largo del rrc

    % y = filter(rrc,1,[r; zeros(Lrrc-1,1)]); %padding de ceros para la cola del filtro, con el tamaño del mismo
    
    
    
    
    % o_data_rx.y = y(delay+1:end-delay)/OVS; %elimina retardo de grupo

    % o_data_rx.o_dws = downsampler(OVS,o_data_rx.y);


%Slicer

    % o_data_rx.ak_hat = slicer(o_data_rx.o_dws,M);


%% Anti Alias Filter

[h_taps_ps ,~] = root_raised_cosine(BR, BR*ovs_ch, rolloff, NTAPS, t0);
aaf_out = filter(h_taps_ps,1, i_rx);

 o_data_rx.y = aaf_out;


%% ADC
tin=(0:length(aaf_out)-1)./(BR*ovs_ch);     %al vector de lo filtrado le sacamos el ovr_ch
tout=(0:1/(BR*ovs_ffe):tin(end)) ;          %creo un vector con ovr_fse
dsp_in = interp1(tin,aaf_out,tout,'linear','extrap');   %interpolo el vector de lo filtrado con el nuevo vec anterior q esta a tasa ovr_fse


%% Digital AGC
agc_out = dsp_in ./ std(dsp_in) * agc_taget;    %a lo interpolado lo divido por la varianza y lo multiplico por un factor que no sabemos q hace 



%% EQ
htaps = zeros(NTAPS_ffe,1);
htaps(floor(NTAPS_ffe/2)-1) = 1; %IMPULSO AL MEDIO

buffer_filter = zeros(NTAPS_ffe,1); %%BUFFER


%%Variables to logging
ffe_out_log = zeros(ceil(Lsymbs*ovs_ffe/FRAME_LOG_2x),1);
error_log = zeros(ceil(Lsymbs/FRAME_LOG_1x),1);
slicer_in_log = zeros(ceil(Lsymbs/FRAME_LOG_1x),1);



for idx=1:length(agc_out)

    buffer_filter(2:end) = buffer_filter(1:end-1);  %0100 -> 100
    buffer_filter(1) = agc_out(idx);                
                                            %antes: [x1 x2 x3 x4] ; después
                                            %del shift: [x1 x1 x2 x3] ;
                                            %después de meter muestra nueva: [x_new x1 x2 x3]
    ffe_out = htaps.'*buffer_filter;                %filtra


    if mod(idx,ovs_ffe)==0                  % calculo el resto, si da 0, continuo    
        idx_new = ceil(idx/ovs_ffe);        %Convierte el índice de muestra idx en índice de símbolo
        slicer_in = ffe_out;                %salida del ffe, a la primera it es el mismo simbolo, pq el filtro es un pulso
        
        o_data_rx.o_dws = slicer_in;


% slicer_out = slicer_QAM_(slicer_in,M);  %paso por el slicer, es el simbolo pero con ruido en la primera iter

        slicer_out = slicer(slicer_in,M);             %este seria el nuestro
        
        if idx_new<time_cma         %primero entramos al cma para dar pasos grandes( lo entreno )
            error =  slicer_in*(abs( slicer_in).^2 - R_CMA); %miro si el error esta lejos del valor esperado R (definido)
            % step = dd_step;
            step = cma_step;

        else
            error =  slicer_in - slicer_out;    %muestra ecualizada - símbolo decidido (lms)
            % step = cma_step;      %creemos que esto estuvo mal 
            step = dd_step;
        end
    
        htaps = (1-leak)*htaps - step*error*conj(buffer_filter);    %Esta es la actualización adaptativa del filtro.

        
        if mod(idx_new,FRAME_LOG_1x)==0     %calculo el resto y lo guardo donde corresponde
            error_log(idx_new/FRAME_LOG_1x) = error;    %debugg errores
            slicer_in_log(idx_new/FRAME_LOG_1x) = slicer_in;    %debugg slicer 
        end

    end
    


    if mod(idx,FRAME_LOG_2x)==0     
        ffe_out_log(idx/FRAME_LOG_2x) = ffe_out;        %debugg ffe(lms)
    end

end


o_data_rx.ak_hat = slicer_out;





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


end



