function [rxs] = carrier_errors(rx, fs, delta_freq, phase_offset, freq_fluct_freq, freq_fluct_amp, phase_tone_amp, phase_tone_freq, LW)
    Ldata = length(rx);
    time = (0:Ldata-1).' .* (1/fs);
    
    % 1. Desvío de Frecuencia Constante (LO Offset)
    if delta_freq ~= 0
        lo_offset = exp(1j * 2 * pi * delta_freq * time);
    else
        lo_offset = ones(Ldata, 1);
    end
    
    % 2. Error de Fase Estático
    static_phase = exp(1j * phase_offset); 
    
    % 3. Fluctuaciones de Frecuencia (Protección contra NaN)
    if freq_fluct_freq == 0
        freq_fluctuations = ones(Ldata, 1);
    else
        freq_fluctuations = exp(1j * (freq_fluct_amp/freq_fluct_freq) .* sin(2*pi*freq_fluct_freq.*time));
    end
    
    % 4. Ruido de Fase (Proceso de Wiener por Linewidth)
    if LW == 0
        osc_pn = ones(Ldata, 1);
    else
        freq_noise = sqrt(2*pi*LW/fs) .* randn(Ldata, 1);
        phase_noise = cumsum(freq_noise); 
        osc_pn = exp(1j .* phase_noise);
    end
    
    % 5. Tono de Fase
    if phase_tone_amp == 0
        phase_tone = ones(Ldata, 1);
    else
        phase_tone = exp(1j .* phase_tone_amp .* sin(2*pi*phase_tone_freq.*time));
    end
    
    % Combinación final de la señal con los errores de portadora
    rxs = rx .* lo_offset .* static_phase .* osc_pn .* freq_fluctuations .* phase_tone;
end