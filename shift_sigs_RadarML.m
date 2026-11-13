%% function s = shift_sigs_RadarML(x,f_shift)
%{
% Summary: 
% Introduce frequency shifts into the Radar ML data
% 
% Inputs:
% x is an array of complex numbers
% f_shift is a scalar value representing the Fourier domain shift in samples
% 
% Outputs:
% s is an array of complex numbers, same size as x
%

wtbuller@gmail.com

%}
function s = shift_sigs_RadarML(x,f_shift)

if abs(f_shift) > length(x)
    error("Requesting frequency shift outside of channel");
end

% The Radar ML data always has some leading noise
% Use that to replicate noise for the Fourier domain background
noiselevel = std(real(x(1:200)));
noisebg = fft((randn(size(x))+1i*randn(size(x)))*noiselevel);

% Oversample Fourier domain using background noise
S_f = [fft(x(:)); noisebg(:)];
S_shift = circshift(S_f,f_shift);
S_nu = S_shift(1:length(x));
s = ifft(S_nu);


%% debugging plot
%{
plot(db(S_f));
hold on;
plot(f0:f0+length(f)-1, db(S_nu));
%}

