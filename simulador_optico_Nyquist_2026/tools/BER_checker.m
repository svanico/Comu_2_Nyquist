function [ber, n_errors] = BER_checker(data_v, ref_v, M, guard)
    
    %--------------------------%
    %           ERRORS
    %--------------------------%
    
    if length(data_v) ~= length(ref_v)
        error('The vectors have different length')
    end

    %--------------------------%
    %          PROCESS
    %--------------------------%

    % Align and guard
    alig_delay = finddelay(ref_v, data_v);
    if alig_delay<0
        alig_delay = 0;
    end
    
    ak_guard_v = ref_v(1+guard:end-alig_delay);
    ak_hat_guard_v = data_v(1+guard+alig_delay:end);
    
    % QAM to bits
    ak_bit_v = qamdemod(ak_guard_v, M, 'OutputType', 'bit');
    ak_hat_bit_v = qamdemod(ak_hat_guard_v, M, 'OutputType', 'bit');
    
    % BER 
    n_errors = sum(ak_bit_v ~= ak_hat_bit_v);
    ber = n_errors / length(ak_bit_v);
    
end
