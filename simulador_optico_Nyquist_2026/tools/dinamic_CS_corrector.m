function [s_out] = dinamic_CS_corrector(s_in)
%%------------------------------------------------------%%
%%--------------------PARAMETERS------------------------%%
%%------------------------------------------------------%%  
        parameters.data_receive=[1];
        parameters.stx=[1];
        parameters.WINDOW_LEN=50;
        parameters.M=16;
%%
%%------------------------------------------------------%%
%%----------------UPLOAD PARAMETERS---------------------%%
%%------------------------------------------------------%%      
fields = fieldnames(s_in); 
    for i = 1:numel(fields)

            parameters.(fields{i}) = s_in.(fields{i});

    end
%%
% Hacerlo con los simbolos alineados
% orx son los simbolos a la salida del slicer
% otx son los simbolos transmitidos
% orx y otx estan alineados
   
WINDOW_LEN = parameters.WINDOW_LEN;
data_out= parameters.data_receive;
stx=parameters.stx;
Ldata = length(data_out);
nblocks = fix(Ldata/WINDOW_LEN);

orx_cs_fixed = zeros(nblocks*WINDOW_LEN,1);
cs_phase = zeros(nblocks,1);
cs_count =0;
last_phase=0;
for nblock=1:nblocks
    slice = (nblock-1)*WINDOW_LEN+1: nblock*WINDOW_LEN;
    rx_block_in = data_out(slice);
    tx_block_in = stx(slice);
    
    min_mse = inf;
    phase_ok = 0;
    for phase_test = [0, pi/2, -pi/2, pi]
        block_test = rx_block_in.*exp(1j*phase_test);
        mse = mean(abs(block_test-tx_block_in).^2);
        if mse < min_mse
            min_mse = mse;
            phase_ok=phase_test;
        end
    end
    if phase_ok ~= last_phase
        s_out.cs_count = cs_count +1;
    end
    last_phase = phase_ok;
    s_out.cs_phase(nblock) = phase_ok; 
    s_out.orx_cs_fixed(slice) = slicer(rx_block_in.*exp(1j*phase_ok),parameters.M);
end
end