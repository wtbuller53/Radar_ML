%% function pdw = iq2pdw(signal, threshold, fsampling, channel_center, bins)
%{
% Summary: generate a pdw from input I/Q signal
% 
% Inputs:
% signal: N length vector of complex values
% threshold: scalar value for detection
% fsampling: scalar sampling frequency
% channel_center: scalar channel frequency used for mixing
% freq_bins: scalar number of frequency bins
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

function pdw = iq2pdw(signal, threshold, fsampling, f_bias, freq_bins)

if ~exist("threshold","var"), threshold = max(abs(signal))/4; end
if ~exist("fsampling","var"), fsampling = 1; end
if ~exist("f_bias","var"), f_bias = 0; end
if ~exist("freq_bins","var"), freq_bins = 256; end 

del_t = 1/fsampling;
freq_resolution = fsampling/freq_bins;
buf_len = 100;
overlap = buf_len - 1;
bufsignal = buffer(signal,buf_len,overlap);

H1 = mean(abs(bufsignal)) > threshold;

t_starts = find(diff(H1) > 0.5);
t_stops = find(diff(H1) < -0.5);

% elide pulses at edge
t_stops(t_stops < t_starts(1)) = [];
t_starts(t_starts > t_stops(end)) = [];

%eliminate short pulses
t_starts((t_stops-t_starts) < 3) =[];
t_stops((t_stops-t_starts) < 3) =[];

if ~isempty(t_starts)
    for ndet = 1:length(t_starts)
        pdw(ndet) = init_pdw();
        pdw(ndet).amp = max(abs(signal));
        % Measure pulse width, bandwidth
        pdw(ndet).toa = t_starts(ndet)*del_t;
        pdw(ndet).pw = (t_stops(ndet)-t_starts(ndet))*del_t;
        sig_detected = signal(t_starts(ndet):t_stops(ndet));
        Sf = abs(fft(sig_detected,freq_bins));
        f_threshold = sqrt(freq_bins)*threshold;
        pdw(ndet).bw = freq_resolution*sum(Sf>f_threshold);
        f_min = find(Sf>f_threshold,1,"first");
        f_max = find(Sf>f_threshold,1,"last");
        pdw(ndet).fc = freq_resolution*(f_min+f_max)/2 + f_bias;
    end
end

end

%% function p = init_pdw()

function p = init_pdw()

    p.toa = [];
    p.aoa = [];
    p.amp =[];
    p.pw = [];
    p.bw = [];
    p.fc = [];
    p.mod = [];
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
% setting threshold to 3 sigma above the noise (assumes the first 200
samples contain only noise
theta = std(sig_shift(1:200))*3;
fs = 3.84e9/32;
pdw = iq2pdw(sig_shift,theta,fs);

%}
