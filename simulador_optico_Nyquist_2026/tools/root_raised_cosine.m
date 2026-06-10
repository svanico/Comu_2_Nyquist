function [t, ipr] = root_raised_cosine(BR, fs, rolloff, Ntaps,t0)
rolloff = rolloff +0.01; % Para evitar los puntos donde el RC no existe
Ts= 1/fs;
T = 1/BR;

if mod(Ntaps,2)==0
    Ntaps=Ntaps+1; %Fuerzo cant de taps impar
end

t= ([-Ntaps/2:1:Ntaps/2].*Ts)+t0;
t_norm = t./T;
ipr = ( sin(pi.*t_norm.*(1-rolloff)) + 4.*rolloff.*t_norm.*cos(pi.*t_norm.*(1+rolloff)) ) ./ ( pi.*t_norm.*(1-(4*rolloff.*t_norm).^2) ) ;
ipr(isnan(ipr)) = 1 + rolloff*(4/pi-1); 

end

