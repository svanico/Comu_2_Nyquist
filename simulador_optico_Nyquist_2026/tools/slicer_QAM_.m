function [z] = slicer_QAM_( x, M )
% SLICER ultra fast for optical communication applications
% Comments are in English for export this code to most important
% corporations in USA. This IS NOT a copy of other source's code.
% Use just only with square constellations.
% Processing of input is column-wise oriented

% Precompute for later use
sqrtM = sqrt(M);

% Inphase/real rail

% Move the real part of input signal; scale appropriately and round the
% values to get index ideal constellation points
realX = round( ((real(x) + (sqrtM-1)) ./ 2) );
% clip values that are outside the valid range
realX(realX <= -1) = 0;
realX(realX > (sqrtM-1)) = sqrtM-1;

% Quadrature/imaginary rail
% Move the imaginary part of input signal; scale appropriately and round
% the values to get index of ideal constellation points
imagX = round(((imag(x) + (sqrtM-1)) ./ 2));
% clip values that are outside the valid range
imagX(imagX <= -1) = 0;
imagX(imagX > (sqrtM-1)) = sqrtM-1;

% Compute the symbol output
z = realX.*2-sqrtM+1 + j.*(imagX.*2-sqrtM+1);


