%% function pdw = iq2pdw(signal, threshold, fsampling, channel_center)
%{
% Summary: generate a pdw from input I/Q signal
% 
% Inputs:
% signal: N length vector of complex values
% threshold: scalar value for detection
% fsampling: scalar sampling frequency
% channel_center: scalar channel frequency used for mixing
% 
% Output:
% pdw(N): structure with common pdw features (scalars) for N detections
%     toa: time of arrival
%     aoa: angle of arrival
%     amp: maximum signal amplitued
%     pw: duration of detected signal
%     fc: middle of frequency occupancy 
%     bw: occupancy of frequency

author: wtbuller@gmail.com
%}

function pdw = iq2pdw(signal, threshold, fsampling, channel_center)

buf_len = 2;
overlap = buf_len - 1;

bufsignal = buffer(signal,buf_len,overlap);
H1 = mean(abs(bufsignal)) > threshold;

t_starts = find(diff(H1) > 0.5);
t_stops = find(diff(H1) < -0.5);

if exist("fsampling","var")
    del_t = 1/fsampling;
else
    del_t = 1;
end

if exist("channel_center","var")
    del_f = channel_center;
else
    del_f = 0;
end


if ~isempty(t_starts)
    for ndet = 1:length(t_starts)
        pdw(ndet) = init_pdw();
        % Measure pulse width, bandwidh
        pdw(ndet).toa = t_starts(ndet)*del_t;
        endofpulse = t_stops(ndet) - t_starts(ndet);
        if ~isempty(endofpulse)
            pdw(ndet).pw = (endofpulse-t_starts(ndet))*del_t;
        else
            pdw(ndet).pw = (length(signal)-t_starts(ndet))*del_t;
        end
        Sf = abs(fft(signal));
        f_threshold = sqrt(length(signal))*threshold;
        pdw(ndet).bw = del_f*sum(Sf>f_threshold)/length(Sf);
        f_min = find(Sf>threshold,1,"first");
        f_max = find(Sf>threshold,1,"last");
        pdw(ndet).fc = fsampling*(f_min+f_max)/(2*length(Sf));
    end
end

end

%% function p = init_pdw()

function p = init_pdw()

    p.toa = [];
    p.aoa = [];
    p.amp =[];
    p.pw = [];
    p.fc = [];
    p.bw = [];

end

%{
Lengthy example to show how you can take an example training data filename,
apply the frequency shift and add noise to the original data and then
generate pdws. Calls to this function should instead be done during
training.

50us_barker7_0Mhz_270Mhz_shift_12933_of_16800_snr_40
n = 1;
arestor_file(n).name = '50us_barker7_0Mhz_270Mhz.npy';
data = readNPY(['/ws1/itar/WaveGen/RadarML/UCLRESM', '/',...
        arestor_file(n).name]);
iq = squeeze(radar_ml_iq(data(1,1,:)));
signal_amplitude = max(abs(iq));
% add the noise level in the file name
snr = 40;
additional_noise_level = signal_amplitude / snr;
sig = iq + ( sqrt(2)^(-1)*additional_noise_level*...
            (randn(length(iq),1)+1i*randn(length(iq),1)) );
shiftIndex = 12933;
Sp0 = fft(sig);
sig_shift = ifft([Sp0(shiftIndex+1:end);Sp0(1:shiftIndex)]);
theta = max(abs(sig_shift))/2;
fs = 3.84e9/32;
pdw = iq2pdw(sig_shift,theta,fs);

%}
