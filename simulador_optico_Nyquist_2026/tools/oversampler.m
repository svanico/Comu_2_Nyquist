function [o_ovs] = oversampler(OVS,Lsyms,ak)
    o_ovs = zeros(OVS*Lsyms,1);
    o_ovs(1:OVS:end) = ak; 
end

