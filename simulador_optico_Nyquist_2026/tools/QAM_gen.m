function [ak] = QAM_gen(M,Lsymbs)
    dec_labels = randi([0 M-1], Lsymbs, 1);
    ak = qammod(dec_labels,M);
end

