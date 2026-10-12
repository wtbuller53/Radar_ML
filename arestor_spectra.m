%% function fiq = arestor_spectra(data)
%{
% Summary:  Plot power spectra from iq data extracted from Radar_ML 
% 
% input: tensor NxMxL, 
%         where N = 3, number of ADC recorders
%               M = 8000, number of waveform transmissions recorded
%               L = 16800, number of iq-samples at ADC at 120 MHz;
% 
% output: fiq, figure handle to plot of spectra

author: wtbuller@gmail.com
example usage:

data = readNPY([radarml_home,'/UCLRESM/100us_cw_0Mhz_250Mhz.npy']);
iq = radar_ml_iq(data);
arestor_spectra(iq);

%}

function fiq = arestor_spectra(iq)

% Define the sample rate
fs = 3.84e9/32;
dt = 1/fs;

% Channel names corresponding to the 3 channels
channel_names = ["ADC0", "ADC2", "ADC4"];

% For development only
nChan = length(channel_names);

fiq = figure;

for adc_n = 1:nChan
    subplot(nChan,1,adc_n);
    spectra_adc = db(fft(squeeze(iq(adc_n,:,:)),[],2));
    imagesc(1e-6*[-fs,fs]/2,[1,size(iq,2)], spectra_adc);
    xlabel('frequency (MHz)');
    ylabel('trial');
    title(channel_names(adc_n));
end
