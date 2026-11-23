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
function s = shift_sigs_RadarML(x,method, nsig)

switch method
    case 'simple'
        theta = mean([max(db(fft(x))),median(db(fft(x)))]);
        [min_shift,max_shift] = shift_limits(db(fft(x)), theta);
        f_shift = randi(max_shift-min_shift) + min_shift;
        S_nu = circshift(fft(x(:)),f_shift);
        s = ifft(S_nu);
    case 'oversample'
        error("Not implemented, yet.")
        % This would allow one to shift a signal partially outside the band
        %{
        y = [x(:); noise*(randn(length(x),1)+1i*(randn(length(x),1)))/sqrt(2)];
        S_f = fft(y(:));
        f_shift = randi(max_shift-min_shift) + min_shift;
        S_shift = circshift(S_f,f_shift);
        S_nu = S_shift(1:length(x));
        s = ifft(S_nu);
        %}
    otherwise
        error("Unknown shift method: %s", method);
end
end


function [a,b] = shift_limits(psi,threshold)
a = 0-find(psi>threshold,1,"first");
b = length(psi)-find(psi>threshold,1,"last");
end