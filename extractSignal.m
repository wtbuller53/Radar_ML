%% function signal = extractSignal(t_series,threshold)
%{
% Summary:  Extract the waveform from a time series with leading and trailing
% noise
% 
% Input: 
% t_series array of length N of complex values
% threshold amplitude value used to identify start and end of signal
% 
% Output:
% signal is a subset of t_series length M < N

%}

function signal = extractSignal(t_series,threshold)

if ~exist("threshold","var")
    threshold = 0.5;
end

s0 = find(abs(t_series)>threshold,1,'first');
s1 = find(abs(t_series)>threshold,1,'last');
signal = t_series(s0:s1);

